#
# Author:: Sean OMeara (<sean@sean.io>)
#
# Copyright (C) 2015, Sean OMeara
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "digest" unless defined?(Digest)
require "json" unless defined?(JSON)
require "kitchen"
require "tmpdir" unless defined?(Dir.mktmpdir)
require "docker"
require "shellwords" unless defined?(Shellwords)
require "base64" unless defined?(Base64)
require_relative "../helpers"

include Dokken::Helpers

# FIXME: - make true
Excon.defaults[:ssl_verify_peer] = false

module Kitchen
  # @see Kitchen::Driver::Dokken
  module Driver
    # Dokken driver for Kitchen.
    #
    # Creates three containers per instance: a *runner*, which the converge
    # actually happens in; a *chef* volume container, whose /opt/chef is
    # mounted into the runner instead of installing chef; and -- only when the
    # docker daemon cannot read the local filesystem -- a *data* container that
    # serves the kitchen sandbox over ssh.
    #
    # @author Sean OMeara <sean@sean.io>
    class Dokken < Kitchen::Driver::Base
      default_config :api_retries, 20
      default_config :binds, []
      default_config :cap_add, nil
      default_config :cap_drop, nil
      default_config :cgroupns_host, false
      default_config :chef_image do |driver|
        case driver.instance.provisioner[:product_name]
        when "cinc"
          "cincproject/cinc"
        else
          "chef/chef"
        end
      end
      default_config :chef_version, "latest"
      default_config :data_image, "dokken/kitchen-cache:latest"
      default_config :data_ssh_port, nil
      default_config :dns, nil
      default_config :dns_search, nil
      default_config :docker_host_url, default_docker_host
      default_config :docker_info do |driver|
        docker_info(driver[:docker_host_url])
      end
      default_config :docker_registry, nil
      default_config :entrypoint, nil
      default_config :env, nil
      default_config :hostname, "dokken"
      default_config :hostname_aliases, nil
      default_config :image_prefix, nil
      default_config :ipv6, false
      default_config :ipv6_subnet, "2001:db8:1::/64" # "2001:db8::/32 Range reserved for documentation"
      default_config :links, nil
      default_config :memory_limit, 0
      default_config :network_mode, "dokken"
      default_config :pid_one_command, 'sh -c "trap exit 0 SIGTERM; while :; do sleep 1; done"'
      default_config :platform, ""
      default_config :ports, nil
      default_config :privileged, false
      default_config :pull_chef_image, true
      default_config :pull_platform_image, true
      default_config :read_timeout, 3600
      default_config :security_opt, nil
      default_config :tmpfs, {}
      default_config :userns_host, false
      default_config :volumes, nil
      default_config :write_timeout, 3600
      default_config :user_ns_mode, nil
      default_config :creds_file, nil
      default_config :docker_config_creds, true

      # (see Base#create)
      #
      # @param state [Hash] mutable instance state
      # @return [void]
      def create(state)
        # Authenticate the private registry
        authenticate!

        # image to config
        pull_platform_image

        # network
        make_dokken_network

        # chef
        pull_chef_image
        create_chef_container state

        # data
        dokken_create_sandbox

        if remote_docker_host? || running_inside_docker?
          make_data_image
          start_data_container state
        end

        # work image
        build_work_image state

        # runner
        start_runner_container state

        # misc
        save_misc_state state
      end

      # (see Base#destroy)
      #
      # The chef volume container and the dokken network are deliberately left
      # behind: both are shared by every instance using the same chef version.
      def destroy(_state)
        if remote_docker_host? || running_inside_docker?
          stop_data_container
          delete_data_container
        end

        stop_runner_container
        delete_runner_container
        delete_work_image
        dokken_delete_sandbox
      end

      private

      # Attach DNS settings to a network endpoint configuration, in place.
      #
      # @param endpoint_config [Hash] the EndpointsConfig entry to extend
      # @return [void]
      def add_dns_config(endpoint_config)
        return unless self[:dns] || self[:dns_search]

        endpoint_config["DNSConfig"] = {}
        endpoint_config["DNSConfig"]["Nameservers"] = self[:dns] if self[:dns]
        endpoint_config["DNSConfig"]["Search"] = self[:dns_search] if self[:dns_search]
      end

      # A Hash that compares equal to any Hash containing all of its pairs.
      #
      # The daemon echoes back more volumes than we asked for, so a plain
      # equality check against the requested set would never match.
      class PartialHash < Hash
        # Whether `other` contains every pair this hash holds.
        #
        # @param other [Object] the value to compare against
        # @return [Boolean] true when `other` is a superset hash
        def ==(other)
          other.is_a?(Hash) && all? { |key, val| other.key?(key) && other[key] == val }
        end
      end

      # How many times to retry a retryable docker API call.
      #
      # @return [Integer] the retry count
      def api_retries
        config[:api_retries]
      end

      # The docker-api connection this driver talks to.
      #
      # @return [::Docker::Connection] a memoised connection
      def docker_connection
        opts = ::Docker.options
        opts[:read_timeout] = config[:read_timeout]
        opts[:write_timeout] = config[:write_timeout]
        @docker_connection ||= ::Docker::Connection.new(config[:docker_host_url], opts)
      end

      # Remove this instance's work image, if nothing else still needs it.
      #
      # @return [void]
      def delete_work_image
        return unless ::Docker::Image.exist?(work_image, { "platform" => oci_platform(config[:platform]) }, docker_connection)

        with_retries { @work_image = ::Docker::Image.get(work_image, { "platform" => oci_platform(config[:platform]) }, docker_connection) }

        with_retries do
          with_retries { @work_image.remove(force: true) }
        rescue ::Docker::Error::ConflictError
          debug "driver - #{work_image} cannot be removed"
        end
      end

      # Build the per-instance image the runner container is created from.
      #
      # @param state [Hash] mutable instance state
      # @return [void]
      # @raise [RuntimeError] if the daemon rejects the build
      def build_work_image(state)
        info("Building work image..")
        return if ::Docker::Image.exist?(work_image, { "platform" => oci_platform(config[:platform]) }, docker_connection)

        begin
          @intermediate_image = ::Docker::Image.build(
            work_image_dockerfile,
            {
              "t" => work_image,
              "platform" => config[:platform],
            },
            docker_connection
          )
        # credit to https://github.com/someara/kitchen-dokken/issues/95#issue-224697526
        rescue Docker::Error::UnexpectedResponseError => e
          msg = "work_image build failed: "
          msg += build_error_detail(e)
          msg += ". The common scenarios are incorrect intermediate "
          msg += "instructions such as not including `-y` on an `apt-get` "
          msg += "or similar. The other common scenario is a transient "
          msg += "error such as an unresponsive mirror."
          raise msg
        # fallback rescue above should catch most of the errors
        rescue => e
          raise "work_image build failed: #{e}"
        end

        state[:work_image] = work_image
      end

      # Pull the human-readable reason out of a failed build response.
      #
      # The daemon usually answers with a JSON document carrying an "error"
      # key, but a proxy or a plain-text 500 does not -- and a JSON::ParserError
      # raised from inside the rescue clause would bury the real failure.
      #
      # @param error [Exception] the error docker-api raised
      # @return [String] the daemon's explanation, or the raw response
      def build_error_detail(error)
        last_line = error.to_s.split("\r\n").last.to_s
        JSON.parse(last_line)["error"].to_s
      rescue JSON::ParserError, TypeError
        last_line
      end

      # The Dockerfile for the work image.
      #
      # @return [String] the Dockerfile contents
      def work_image_dockerfile
        from = registry_image_path(platform_image)
        debug("driver - Building work image from #{from}")
        dockerfile_contents = [
          "FROM #{from}",
          "LABEL X-Built-By=kitchen-dokken X-Built-From=#{platform_image}",
        ]
        Array(config[:intermediate_instructions]).each do |c|
          dockerfile_contents << c
        end
        dockerfile_contents.join("\n")
      end

      # Record the values the transport, provisioner and verifier read later.
      #
      # @param state [Hash] mutable instance state
      # @return [void]
      def save_misc_state(state)
        state[:platform_image] = platform_image
        state[:instance_name] = instance_name
        state[:instance_platform_name] = instance_platform_name
        state[:image_prefix] = image_prefix
      end

      # Delete the shared chef volume container.
      #
      # Not called during {#destroy}; it exists for callers that really do want
      # to reclaim the shared container.
      #
      # @return [void]
      def delete_chef_container
        debug "driver - deleting container #{chef_container_name}"
        delete_container chef_container_name
      end

      # Delete this instance's data container.
      #
      # @return [void]
      def delete_data_container
        debug "driver - deleting container #{data_container_name}"
        delete_container data_container_name
      end

      # Delete this instance's runner container.
      #
      # @return [void]
      def delete_runner_container
        debug "driver - deleting container #{runner_container_name}"
        delete_container runner_container_name
      end

      # The configured image name prefix, if any.
      #
      # @return [String, nil] the prefix
      def image_prefix
        config[:image_prefix]
      end

      # The kitchen platform name, e.g. `almalinux-9`.
      #
      # @return [String] the platform name
      def instance_platform_name
        instance.platform.name
      end

      # Stop this instance's runner container.
      #
      # @return [void]
      def stop_runner_container
        debug "driver - stopping container #{runner_container_name}"
        stop_container runner_container_name
      end

      # Stop this instance's data container.
      #
      # @return [void]
      def stop_data_container
        debug "driver - stopping container #{data_container_name}"
        stop_container data_container_name
      end

      # The name of the per-instance image the runner is created from.
      #
      # @return [String] a lowercase image name
      def work_image
        [image_prefix, instance_name].compact.join("/").downcase
      end

      # The `Tmpfs` value for the runner container.
      #
      # @return [Hash, nil] a Docker API Tmpfs hash
      def dokken_tmpfs
        coerce_tmpfs(config[:tmpfs])
      end

      # Normalise a `tmpfs:` setting into a Docker API Tmpfs hash.
      #
      # @param v [Hash, Array<String>, nil] the configured tmpfs mounts
      # @return [Hash, nil] a Tmpfs hash, or nil to omit the key
      def coerce_tmpfs(v)
        case v
        when Hash, nil
          v
        else
          Array(v).each_with_object({}) do |y, h|
            name, opts = y.split(":", 2)
            h[name.to_s] = opts.to_s
          end
        end
      end

      # The containers whose volumes the runner mounts.
      #
      # @return [Array<String>] container names
      def dokken_volumes_from
        ret = []
        ret << chef_container_name
        ret << data_container_name if remote_docker_host? || running_inside_docker?
        ret
      end

      # Split a `volumes:` setting into anonymous volumes and bind mounts.
      #
      # Entries containing a colon are bind mounts and are moved into `binds`;
      # what is left becomes the `Volumes` hash. `binds` is mutated in place.
      #
      # @param v [Hash, Array<String>, nil] the configured volumes
      # @param binds [Array] the bind list to append to
      # @return [Hash, nil] a Volumes hash, or nil to omit the key
      def coerce_volumes(v, binds)
        case v
        when PartialHash, nil
          v
        when Hash
          PartialHash[v]
        else
          b = []
          v.delete_if do |x|
            parts = x.split(":")
            b << x if parts.length > 1
          end
          b = nil if b.empty?
          binds.push(b) unless binds.include?(b) || b.nil?
          return PartialHash.new if v.empty?

          v.each_with_object(PartialHash.new) { |volume, h| h[volume] = {} }
        end
      end

      # Work out the runner container's `Volumes` and `Binds` values.
      #
      # The sandboxes are only bind-mounted when the daemon can read the host
      # filesystem; otherwise the transport ships them into the data container.
      #
      # @return [Array(Hash, Array<String>)] the volumes and binds
      def calc_volumes_binds
        # Array() on a Hash yields its pairs, which would destroy an explicit
        # `volumes:` mapping before coerce_volumes ever sees it.
        configured_volumes = config[:volumes]
        volumes = configured_volumes.is_a?(Hash) ? configured_volumes : Array.new(Array(configured_volumes))
        binds = Array.new(Array(config[:binds]))

        # Binds is mutated in-place, volumes *may* be.
        volumes = coerce_volumes(volumes, binds)

        binds_ret = []
        binds_ret << "#{dokken_kitchen_sandbox}:#{resolved_root_path}" unless dokken_kitchen_sandbox.nil? || remote_docker_host? || running_inside_docker?
        binds_ret << "#{dokken_verifier_sandbox}:/opt/verifier" unless dokken_verifier_sandbox.nil? || remote_docker_host? || running_inside_docker?
        binds_ret << binds unless binds.nil?

        [volumes, binds_ret.flatten]
      end

      # Create and start the container the converge actually runs in.
      #
      # @param state [Hash] mutable instance state
      # @return [void]
      def start_runner_container(state)
        debug "driver - starting #{runner_container_name}"

        volumes, binds = calc_volumes_binds

        config = {
          "name" => runner_container_name,
          "Cmd" => Shellwords.shellwords(self[:pid_one_command]),
          # locally built image, must use short-name
          "Image" => short_image_path(work_image),
          "Hostname" => self[:hostname],
          "Env" => self[:env],
          "ExposedPorts" => exposed_ports,
          "Volumes" => volumes,
          "HostConfig" => {
            "Privileged" => self[:privileged],
            "VolumesFrom" => dokken_volumes_from,
            "Binds" => binds,
            "Dns" => self[:dns],
            "DnsSearch" => self[:dns_search],
            "Links" => Array(self[:links]),
            "CapAdd" => Array(self[:cap_add]),
            "CapDrop" => Array(self[:cap_drop]),
            "SecurityOpt" => Array(self[:security_opt]),
            "NetworkMode" => self[:network_mode],
            "PortBindings" => port_bindings,
            "Tmpfs" => dokken_tmpfs,
            "Memory" => self[:memory_limit],
          },
        }
        unless %w{host bridge}.include?(self[:network_mode])
          endpoint_config = {
            "Aliases" => Array(self[:hostname]).concat(Array(self[:hostname_aliases])),
          }
          add_dns_config(endpoint_config)
          config["NetworkingConfig"] = {
            "EndpointsConfig" => {
              self[:network_mode] => endpoint_config,
            },
          }
        end
        unless self[:entrypoint].to_s.empty?
          config["Entrypoint"] = self[:entrypoint]
        end
        if self[:cgroupns_host]
          config["HostConfig"]["CgroupnsMode"] = "host"
        end
        if self[:userns_host]
          config["HostConfig"]["UsernsMode"] = "host"
        end

        if self[:privileged]
          if self[:user_ns_mode] != "host"
            debug "driver - privileged mode is not supported with user namespaces enabled"
            debug "driver - changing UsernsMode from '#{self[:user_ns_mode]}' to 'host'"
          end
          config["HostConfig"]["UsernsMode"] = "host"
        end

        runner_container = run_container(config, platform: self[:platform])
        state[:runner_container] = runner_container.json
      end

      # Create and start the container that serves the sandboxes over ssh.
      #
      # @param state [Hash] mutable instance state
      # @return [void]
      def start_data_container(state)
        debug "driver - creating #{data_container_name}"
        config = {
          "name" => data_container_name,
          # locally built image, must use short-name
          "Image" => short_image_path(data_image),
          "HostConfig" => {
            "PortBindings" => data_port_bindings,
            "PublishAllPorts" => self[:data_ssh_port].nil?,
            "NetworkMode" => "bridge",
          },
        }
        unless %w{host bridge}.include?(self[:network_mode])
          endpoint_config = {
            "Aliases" => Array(self[:hostname]),
          }
          add_dns_config(endpoint_config)
          config["NetworkingConfig"] = {
            "EndpointsConfig" => {
              self[:network_mode] => endpoint_config,
            },
          }
        end
        # Deliberately not pinned to config[:platform]: this container only
        # serves kitchen's files over ssh, so its architecture is irrelevant to
        # the system under test. The data image is built locally from
        # almalinux:9 (see Helpers#create_data_image) and is therefore always
        # host-architecture -- pinning it fails outright whenever the platform
        # under test differs from the host.
        data_container = run_container(config)
        state[:data_container] = data_container.json
      end

      # Create the shared `dokken` network, unless it already exists.
      #
      # Several instances converge in parallel and all race to create the one
      # shared network, so this is both file-locked and forgiving of a lost race.
      #
      # @return [void]
      def make_dokken_network
        return unless self[:network_mode] == "dokken"

        with_file_lock("#{home_dir}/.dokken-network.lock") do
          with_retries { ::Docker::Network.get("dokken", {}, docker_connection) }
        rescue ::Docker::Error::NotFoundError
          begin
            with_retries { ::Docker::Network.create("dokken", network_settings) }
          rescue ::Docker::Error::DockerError => e
            debug "driver - error :#{e}:"
          end
        end
      end

      # Build the data image, unless it is already present.
      #
      # @return [void]
      def make_data_image
        debug "driver - calling create_data_image"
        create_data_image(config[:docker_registry])
      end

      # Create the volume container /opt/chef is mounted into the runner from.
      #
      # The container is shared by every instance on the same chef version and
      # platform, so creation is guarded by a file lock.
      #
      # @param state [Hash] mutable instance state
      # @return [void]
      # @raise [RuntimeError] if the container could not be created
      def create_chef_container(state)
        with_file_lock("#{home_dir}/.dokken-#{chef_container_name}.lock") do
          with_retries do
            # TEMPORARY FIX - docker-api 2.0.0 has a buggy Docker::Container.get - use .all instead
            # https://github.com/swipely/docker-api/issues/566
            # ::Docker::Container.get(chef_container_name, {}, docker_connection)
            found = ::Docker::Container.all({ all: true }, docker_connection).select { |c| c.info["Names"].include?("/#{chef_container_name}") }
            raise ::Docker::Error::NotFoundError.new(chef_container_name) if found.empty?

            debug "Chef container already exists, continuing"
          end
        rescue ::Docker::Error::NotFoundError
          debug "Chef container does not exist, creating a new Chef container"
          with_retries do
            debug "driver - creating volume container #{chef_container_name} from #{chef_image}"
            config = {
              "name" => chef_container_name,
              "Cmd" => ["true"],
              "Image" => registry_image_path(chef_image),
              "HostConfig" => {
                "NetworkMode" => self[:network_mode],
              },
            }
            # /opt/chef from this container is mounted into the runner, so it
            # has to be built for the same architecture as the runner.
            chef_container = create_container(config, platform: self[:platform])
            state[:chef_container] = chef_container.json
          # Both constants have to be spelled out: bare `StandardError` inside
          # module Kitchen resolves to Kitchen::StandardError, and Docker::Error
          # is a namespace module that no exception class includes.
          rescue ::Docker::Error::DockerError, ::StandardError => e
            raise "driver - #{chef_container_name} failed to create #{e}"
          end
        end
      end

      # Run a block holding an exclusive lock on a file.
      #
      # @param path [String] the lock file to create and hold
      # @yield with the lock held
      # @return [void]
      def with_file_lock(path)
        File.open(path, File::RDWR | File::CREAT, 0o644) do |f|
          f.flock(File::LOCK_EX)
          yield
        end
      end

      # Log the docker client in, when a creds_file has been configured.
      #
      # @return [void]
      def authenticate!
        # No need to authenticate if the credentials are empty
        return if docker_creds.empty?

        ::Docker.authenticate! docker_creds
      end

      # The credentials read from the configured creds_file.
      #
      # @return [Hash] the credentials, or an empty hash
      def docker_creds
        @docker_creds ||= if config[:creds_file]
                            JSON.parse(IO.read(config[:creds_file]))
                          else
                            {}
                          end
      end

      # The credentials found in ~/.docker/config.json, keyed by registry.
      #
      # `auths` entries resolve to a credentials hash; `credHelpers` entries
      # resolve to a proc that shells out to the helper only if it is needed.
      #
      # @return [Hash{String => Hash, Proc}] credentials by registry key
      def docker_config_creds
        return @docker_config_creds if @docker_config_creds

        @docker_config_creds = {}
        config_file = ::File.join(::Dir.home, ".docker", "config.json")
        if ::File.exist?(config_file)
          config = JSON.load_file!(config_file)
          if config["auths"]
            config["auths"].each do |k, v|
              next if v["auth"].nil?

              # Split once: a colon is legal inside a registry password.
              username, password = Base64.decode64(v["auth"]).split(":", 2)
              @docker_config_creds[k] = { serveraddress: k, username:, password: }
            end
          end

          if config["credHelpers"]
            config["credHelpers"].each do |k, v|
              @docker_config_creds[k] = Proc.new do
                c = JSON.parse(`echo #{k} | docker-credential-#{v} get`)
                { serveraddress: c["ServerURL"], username: c["Username"], password: c["Secret"] }
              end
            end
          end
        else
          debug("~/.docker/config.json does not exist")
        end

        @docker_config_creds
      end

      # The `auths` key `docker login` itself writes for Docker Hub.
      DOCKER_HUB_REGISTRY_KEY = "https://index.docker.io/v1/".freeze

      # Registry hosts that all refer to Docker Hub. Docker writes the legacy
      # v1 URL above, but hand-written and tool-generated configs use any of
      # these. Listed in preference order.
      DOCKER_HUB_HOSTS = %w{index.docker.io docker.io registry-1.docker.io}.freeze

      # An explicit "no credentials" value. Returning nil here instead would let
      # docker-api fall back to the process-global ::Docker.creds, which
      # authenticate! populates from creds_file and never clears -- so another
      # instance's private registry password would be sent to this registry,
      # which is the very leak this scoping exists to prevent.
      NO_DOCKER_CREDS = {}.freeze

      # Return the registry host an image reference points at, or nil when the
      # reference resolves to Docker Hub. The leading path component only names
      # a registry when it contains a "." or a ":", or is exactly "localhost" --
      # the same heuristic Docker uses to tell "quay.io/org/image" apart from
      # the Hub shorthand "dokken/almalinux-8".
      #
      # @param image [String] an image reference
      # @return [String, nil] the registry host, or nil for Docker Hub
      def image_registry_host(image)
        first, remainder = image.split("/", 2)
        return nil if remainder.nil?
        return nil unless first.include?(".") || first.include?(":") || first == "localhost"

        first
      end

      # Look up the ~/.docker/config.json entry that applies to an image's
      # registry. Returns nil when that registry has no entry so the pull is
      # attempted anonymously, rather than offering it another registry's
      # credentials.
      # Pick the config.json key that holds the Docker Hub credentials. A
      # config may spell Hub several ways, so prefer the canonical key and then
      # a fixed alias order rather than whichever happens to be listed first.
      # @return [String, nil] the config.json key holding Docker Hub credentials
      def docker_hub_creds_key
        keys = docker_config_creds.keys.select { |k| DOCKER_HUB_HOSTS.include?(parse_registry_host(k)) }
        return if keys.empty?

        keys.find { |k| k == DOCKER_HUB_REGISTRY_KEY } ||
          keys.min_by { |k| DOCKER_HUB_HOSTS.index(parse_registry_host(k)) }
      end

      # The ~/.docker/config.json credentials that apply to an image.
      #
      # @param image [String] an image reference
      # @return [Hash, nil] the credentials, or nil when none apply
      def docker_config_creds_for_image(image)
        host = image_registry_host(image)

        key = if host.nil? || DOCKER_HUB_HOSTS.include?(host)
                docker_hub_creds_key
              else
                docker_config_creds.keys.find { |k| parse_registry_host(k) == host }
              end
        return if key.nil?

        c = docker_config_creds[key]
        c.respond_to?(:call) ? c.call : c
      end

      # The credentials to send when pulling an image.
      #
      # @param image [String] an image reference
      # @return [Hash] credentials, or {NO_DOCKER_CREDS} to pull anonymously
      def docker_creds_for_image(image)
        return docker_creds if config[:creds_file]
        return NO_DOCKER_CREDS unless config[:docker_config_creds]

        docker_config_creds_for_image(image) || NO_DOCKER_CREDS
      end

      # Pull the platform image the work image is built from.
      #
      # @return [void]
      def pull_platform_image
        debug "driver - pulling #{short_image_path(platform_image)}"
        config[:pull_platform_image] ? pull_image(platform_image) : pull_if_missing(platform_image)
      end

      # Pull the chef/cinc image the volume container is built from.
      #
      # @return [void]
      def pull_chef_image
        debug "driver - pulling #{short_image_path(chef_image)}"
        config[:pull_chef_image] ? pull_image(chef_image) : pull_if_missing(chef_image)
      end

      # Force-remove an image.
      #
      # @param name [String] an image reference
      # @return [void]
      def delete_image(name)
        with_retries { @image = ::Docker::Image.get(name, { "platform" => oci_platform(config[:platform]) }, docker_connection) }
        with_retries { @image.remove(force: true) }
      rescue ::Docker::Error::DockerError
        puts "Image #{name} not found. Nothing to delete."
      end

      # Whether the daemon knows about a container.
      #
      # @param name [String] the container name
      # @return [Boolean] true when the container exists
      def container_exist?(name)
        true if ::Docker::Container.get(name, {}, docker_connection)
      rescue ::StandardError
        false
      end

      # Split an image reference into its repo and tag.
      #
      # @param image [String] the docker image path to parse
      # @return [Array(String, String)] the repo and tag
      def parse_image_name(image)
        repo, separator, tag = image.rpartition(":")

        # A colon before a slash delimits a registry port, not a tag:
        # "localhost:5000/almalinux" is an untagged image on a local registry.
        return [image, "latest"] if separator.empty? || tag.include?("/")

        [repo, tag]
      end

      # Return the 'repo' half of a docker image path. Agnostic about if a
      # registry is included, this effectively is just "before the colon"
      #
      # @param image [String] the docker image path to parse
      # @return [String] the repo portion of `image`
      def repo(image)
        parse_image_name(image)[0]
      end

      # Return the 'tag' of a docker image path. Will be `latest` if there
      # is no explicit tag in the image path.
      #
      # @param image [String] the docker image path to parse
      # @return [String] the tag of `image`
      def tag(image)
        parse_image_name(image)[1]
      end

      # Ensures an explicit tag on an image path.
      #
      # @param image [String] the docker image path to parse
      # @return [String] `repo`:`tag`
      def short_image_path(image)
        "#{repo(image)}:#{tag(image)}"
      end

      # Qualifies the results of `short_image_path` with any registry the
      # user has requested
      #
      # @param image [String] the docker image path to parse
      # @return [String] The most fully-qualified registry path we cn make
      def registry_image_path(image)
        if config[:docker_registry]
          "#{config[:docker_registry]}/#{short_image_path(image)}"
        else
          short_image_path(image)
        end
      end

      # Fetch a container by name, creating it if it does not exist.
      #
      # @param args [Hash] the `/containers/create` body
      # @param platform [String, nil] an OCI platform to pin the container to
      # @return [::Docker::Container] the container
      # @raise [RuntimeError] if the container could not be created
      def create_container(args, platform: nil)
        with_retries { @container = ::Docker::Container.get(args["name"], {}, docker_connection) }
      rescue ::Docker::Error::NotFoundError
        with_retries do
          # Merge rather than append: start_runner_container passes config[:env]
          # straight through, so mutating args["Env"] would edit the driver's
          # own configuration -- and stamp it again on every retry.
          create_args = args.merge("Env" => Array(args["Env"]) + container_env)
          info "Creating container #{args["name"]}"
          debug "driver - create_container args #{create_args}"
          with_retries do
            @container = create_container_for_platform(create_args, platform)
          rescue ::Docker::Error::ConflictError
            debug "driver - rescue ConflictError: #{args["name"]}"
            with_retries { @container = ::Docker::Container.get(args["name"], {}, docker_connection) }
          end
        rescue ::Docker::Error::DockerError => e
          debug "driver - error :#{e}:"
          raise "driver - failed to create_container #{args["name"]}"
        end
      end

      # Environment variables kitchen-dokken stamps onto every container it
      # creates, so that recipes and tests can tell they are running under
      # Test Kitchen.
      #
      # @return [Array<String>] `KEY=value` strings
      def container_env
        env = ["TEST_KITCHEN=1"]
        env << "CI=#{ENV["CI"]}" if ENV.include? "CI"
        env
      end

      # Create a container, optionally pinned to an OCI platform.
      #
      # /containers/create takes `platform` as a *query* parameter, but
      # Docker::Container.create only ever forwards `name` to the query string
      # and dumps everything else into the request body. A "Platform" body key
      # is therefore accepted and silently ignored by the daemon, which is why
      # the platform config had no effect on container creation. Post directly
      # when a platform is wanted; otherwise use the gem as before.
      #
      # @param args [Hash] the `/containers/create` body
      # @param platform [String, nil] an OCI platform such as `linux/arm64/v8`
      # @return [::Docker::Container] the created container
      def create_container_for_platform(args, platform)
        return ::Docker::Container.create(args, docker_connection) if platform.to_s.empty?

        query = { "name" => args["name"], "platform" => platform }
        body = args.reject { |k, _| k == "name" }
        docker_connection.post("/containers/create", query, body: JSON.dump(body))
        ::Docker::Container.get(args["name"], {}, docker_connection)
      end

      # Create a container if needed, then start it and wait for it to run.
      #
      # @param args [Hash] the `/containers/create` body
      # @param platform [String, nil] an OCI platform to pin the container to
      # @return [::Docker::Container] the running container
      # @raise [Kitchen::ActionFailed] if the container will not stay running
      def run_container(args, platform: nil)
        @container = create_container(args, platform: platform)
        with_retries do
          @container.start
          @container = ::Docker::Container.get(args["name"], {}, docker_connection)
          wait_running_state(args["name"], true)
        end
        assert_running!(args["name"])
        @container
      end

      # Fail the action when a container that has to run is not running.
      #
      # wait_running_state stops polling as soon as `FinishedAt` is set, which
      # is precisely the case for a container whose pid 1 exited -- so without
      # this check `kitchen create` reported success and exited 0, leaving the
      # user to discover the problem at converge as a bare docker API message:
      # "container dd55d579... is not running". A container id, no instance
      # name, and no clue that pid 1 was the cause.
      #
      # Only containers that must actually run reach here; the chef container
      # is a volume and is never started.
      #
      # @param name [String] the container name
      # @return [void]
      # @raise [Kitchen::ActionFailed] if the container is not running
      def assert_running!(name)
        return if container_state["Running"]

        raise ActionFailed,
          "The #{name} container exited immediately after being started. " \
          "Its pid 1 did not stay up: check `pid_one_command`, `entrypoint`, " \
          "and that the image can boot (`docker logs #{name}` shows why)."
      end

      # The current container's `State` payload.
      #
      # @return [Hash] the state, or an empty hash if there is no container
      def container_state
        @container ? @container.info["State"] : {}
      end

      # Stop a container and wait for it to leave the running state.
      #
      # @param name [String] the container name
      # @return [void]
      def stop_container(name)
        with_retries { @container = ::Docker::Container.get(name, {}, docker_connection) }
        with_retries do
          @container.stop(force: false)
          wait_running_state(name, false)
        end
      rescue ::Docker::Error::NotFoundError
        debug "Container #{name} not found. Nothing to stop."
      end

      # Force-remove a container along with its anonymous volumes.
      #
      # @param name [String] the container name
      # @return [void]
      def delete_container(name)
        with_retries { @container = ::Docker::Container.get(name, {}, docker_connection) }
        with_retries { @container.delete(force: true, v: true) }
      rescue ::Docker::Error::NotFoundError
        debug "Container #{name} not found. Nothing to delete."
      end

      # Poll a container until it reaches the wanted running state.
      #
      # Gives up after a bounded number of polls rather than blocking a converge
      # forever, and stops early once the container has actually finished.
      #
      # @param name [String] the container name
      # @param v [Boolean] the running state to wait for
      # @return [void]
      def wait_running_state(name, v)
        @container = ::Docker::Container.get(name, {}, docker_connection)
        i = 0
        tries = 20
        until container_state["Running"] == v || container_state["FinishedAt"] != "0001-01-01T00:00:00Z"
          i += 1
          break if i == tries

          sleep 0.1
          @container = ::Docker::Container.get(name, {}, docker_connection)
        end
      end

      # The name of the shared chef volume container.
      #
      # @return [String] the container name
      def chef_container_name
        prefix = instance.provisioner[:product_name] == "cinc" ? "cinc" : "chef"
        # `platform: ~` in a kitchen.yml yields nil rather than the "" default.
        platform = config[:platform].to_s
        return "#{prefix}-#{chef_version}" if platform.empty?

        "#{prefix}-#{chef_version}-#{platform.tr("/", "-")}"
      end

      # The chef/cinc image the volume container is built from.
      #
      # @return [String] an image reference
      def chef_image
        "#{config[:chef_image]}:#{chef_version}"
      end

      # The chef version to use, as an image tag.
      #
      # @return [String] a tag
      def chef_version
        return "latest" if config[:chef_version] == "stable"

        config[:chef_version]
      end

      # The name of this instance's data container.
      #
      # @return [String] the container name
      def data_container_name
        "#{instance_name}-data"
      end

      # The image the data container is built from.
      #
      # @return [String] an image reference
      def data_image
        config[:data_image]
      end

      # The `PortBindings` value for the data container.
      #
      # @return [Hash] a Docker API PortBindings hash
      def data_port_bindings
        return port_bindings unless config[:data_ssh_port]

        # If data_ssh_port is specified, use it for SSH port mapping
        ssh_port_binding = {
          "22/tcp" => [
            {
              "HostIp" => "0.0.0.0",
              "HostPort" => config[:data_ssh_port].to_s,
            },
          ],
        }

        # Merge with any existing port bindings
        if port_bindings
          port_bindings.merge(ssh_port_binding)
        else
          ssh_port_binding
        end
      end

      # The base image for the platform under test.
      #
      # @return [String] an image reference
      def platform_image
        config[:image] || platform_image_from_name
      end

      # Derive an image reference from the kitchen platform name.
      #
      # @return [String] an image reference
      def platform_image_from_name
        platform, release = instance.platform.name.split("-")
        release ? [platform, release].join(":") : platform
      end

      # Pull an image only when the daemon does not already have it.
      #
      # @param image [String] an image reference
      # @return [void]
      def pull_if_missing(image)
        return if ::Docker::Image.exist?(registry_image_path(image), { "platform" => oci_platform(config[:platform]) }, docker_connection)

        pull_image image
      end

      # https://github.com/docker/docker/blob/4fcb9ac40ce33c4d6e08d5669af6be5e076e2574/registry/auth.go#L231
      # Reduce a config.json registry key to a bare host.
      #
      # @param val [String] a registry key, possibly a URL
      # @return [String] the host
      def parse_registry_host(val)
        val.sub(%r{https?://}, "").split("/").first
      end

      # Pull an image from its registry.
      #
      # @param image [String] an image reference
      # @return [Boolean] true when the pull changed what is on disk
      def pull_image(image)
        path = registry_image_path(image)
        with_retries do
          if Docker::Image.exist?(path, { "platform" => oci_platform(config[:platform]) }, docker_connection)
            original_image = Docker::Image.get(path, { "platform" => oci_platform(config[:platform]) }, docker_connection)
          end

          new_image = Docker::Image.create({ "fromImage" => path, "platform" => config[:platform] }, docker_creds_for_image(path), docker_connection)

          !(original_image&.id&.start_with?(new_image.id))
        end
      end

      # Convert an "os/arch[/variant]" platform string into the JSON OCI
      # platform spec the Docker API expects as an image filter. The variant
      # matters: the daemon will not match a filter of
      # {"os":"linux","architecture":"amd64"} against a linux/amd64/v2 image,
      # so dropping it makes every image lookup for a variant image miss.
      #
      # @param platform [String, nil] an "os/arch[/variant]" string
      # @return [String, nil] a JSON OCI platform spec, or the input unchanged
      def oci_platform(platform)
        return platform if platform.nil? || !platform.include?("/")

        os, architecture, variant = platform.split("/")
        spec = { os: os, architecture: architecture }
        spec[:variant] = variant unless variant.nil? || variant.empty?
        spec.to_json
      end

      # The name of this instance's runner container.
      #
      # @return [String] the container name
      def runner_container_name
        instance_name.to_s
      end

      # Retry a docker API call through the errors that retrying can fix.
      #
      # @yield the API call to attempt
      # @return [Object] the block's value
      # @raise [::Docker::Error::DockerError] if every attempt failed
      def with_retries
        tries = api_retries
        begin
          yield
        # Only catch errors that can be fixed with retries.
        rescue ::Docker::Error::ServerError, # 404
               ::Docker::Error::UnexpectedResponseError, # 400
               ::Docker::Error::TimeoutError,
               ::Docker::Error::IOError => e
          tries -= 1
          sleep 0.1
          retry if tries > 0
          debug "tries: #{tries} error: #{e}"
          raise e
        end
      end
    end
  end
end
