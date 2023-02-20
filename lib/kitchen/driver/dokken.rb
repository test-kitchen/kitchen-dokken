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
require "kitchen"
require "tmpdir" unless defined?(Dir.mktmpdir)
require "docker"
require "lockfile"
require "base64" unless defined?(Base64)
require_relative "../helpers"

include Dokken::Helpers

# FIXME: - make true
Excon.defaults[:ssl_verify_peer] = false

module Kitchen
  module Driver
    # Dokken driver for Kitchen.
    #
    # @author Sean OMeara <sean@sean.io>
    class Dokken < Kitchen::Driver::Base
      default_config :api_retries, 20
      default_config :binds, []
      default_config :cap_add, nil
      default_config :cap_drop, nil
      default_config :cgroupns_host, false
      default_config :chef_image, "chef/chef"
      default_config :chef_version, "latest"
      default_config :data_image, "dokken/kitchen-cache:latest"
      default_config :dns, nil
      default_config :dns_search, nil
      default_config :docker_host_url, default_docker_host
      default_config :docker_info, docker_info
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
      default_config :docker_config_creds, false

      # (see Base#create)
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

        if remote_docker_host?
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

      def destroy(_state)
        if remote_docker_host?
          stop_data_container
          delete_data_container
        end

        stop_runner_container
        delete_runner_container
        delete_work_image
        dokken_delete_sandbox
      end

      private

      class PartialHash < Hash
        def ==(other)
          other.is_a?(Hash) && all? { |key, val| other.key?(key) && other[key] == val }
        end
      end

      def api_retries
        config[:api_retries]
      end

      def docker_connection
        opts = ::Docker.options
        opts[:read_timeout] = config[:read_timeout]
        opts[:write_timeout] = config[:write_timeout]
        @docker_connection ||= ::Docker::Connection.new(config[:docker_host_url], opts)
      end

      def delete_work_image
        return unless ::Docker::Image.exist?(work_image, { "platform" => config[:platform] }, docker_connection)

        with_retries { @work_image = ::Docker::Image.get(work_image, { "platform" => config[:platform] }, docker_connection) }

        with_retries do
          with_retries { @work_image.remove(force: true) }
        rescue ::Docker::Error::ConflictError
          debug "driver - #{work_image} cannot be removed"
        end
      end

      def build_work_image(state)
        info("Building work image..")
        return if ::Docker::Image.exist?(work_image, { "platform" => config[:platform] }, docker_connection)

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
          msg += JSON.parse(e.to_s.split("\r\n").last)["error"].to_s
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

      def save_misc_state(state)
        state[:platform_image] = platform_image
        state[:instance_name] = instance_name
        state[:instance_platform_name] = instance_platform_name
        state[:image_prefix] = image_prefix
      end

      def delete_chef_container
        debug "driver - deleting container #{chef_container_name}"
        delete_container chef_container_name
      end

      def delete_data_container
        debug "driver - deleting container #{data_container_name}"
        delete_container data_container_name
      end

      def delete_runner_container
        debug "driver - deleting container #{runner_container_name}"
        delete_container runner_container_name
      end

      def image_prefix
        config[:image_prefix]
      end

      def instance_platform_name
        instance.platform.name
      end

      def stop_runner_container
        debug "driver - stopping container #{runner_container_name}"
        stop_container runner_container_name
      end

      def stop_data_container
        debug "driver - stopping container #{data_container_name}"
        stop_container data_container_name
      end

      def work_image
        return "#{image_prefix}/#{instance_name}" unless image_prefix.nil?

        instance_name
      end

      def dokken_binds
        ret = []
        ret << "#{dokken_kitchen_sandbox}:/opt/kitchen" unless dokken_kitchen_sandbox.nil? || remote_docker_host?
        ret << "#{dokken_verifier_sandbox}:/opt/verifier" unless dokken_verifier_sandbox.nil? || remote_docker_host?
        ret << Array(config[:binds]) unless config[:binds].nil?
        ret.flatten
      end

      def dokken_tmpfs
        coerce_tmpfs(config[:tmpfs])
      end

      def dokken_volumes
        coerce_volumes(config[:volumes])
      end

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

      def coerce_volumes(v)
        case v
        when PartialHash, nil
          v
        when Hash
          PartialHash[v]
        else
          b = []
          v = Array(v).to_a # in case v.is_A?(Chef::Node::ImmutableArray)
          v.delete_if do |x|
            parts = x.split(":")
            b << x if parts.length > 1
          end
          b = nil if b.empty?
          config[:binds].push(b) unless config[:binds].include?(b) || b.nil?
          return PartialHash.new if v.empty?

          v.each_with_object(PartialHash.new) { |volume, h| h[volume] = {} }
        end
      end

      def dokken_volumes_from
        ret = []
        ret << chef_container_name
        ret << data_container_name if remote_docker_host?
        ret
      end

      def start_runner_container(state)
        debug "driver - starting #{runner_container_name}"

        config = {
          "name" => runner_container_name,
          "Cmd" => Shellwords.shellwords(self[:pid_one_command]),
          # locally built image, must use short-name
          "Image" => short_image_path(work_image),
          "Hostname" => self[:hostname],
          "Env" => self[:env],
          "ExposedPorts" => exposed_ports,
          "Volumes" => dokken_volumes,
          "HostConfig" => {
            "Privileged" => self[:privileged],
            "VolumesFrom" => dokken_volumes_from,
            "Binds" => dokken_binds,
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
          "NetworkingConfig" => {
            "EndpointsConfig" => {
              self[:network_mode] => {
                "Aliases" => Array(self[:hostname]).concat(Array(self[:hostname_aliases])),
              },
            },
          },
        }
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
          if self[:user_ns_mode] != 'host'
            debug "driver - privileged mode is not supported with user namespaces enabled"
            debug "driver - changing UsernsMode from '#{self[:user_ns_mode]}' to 'host'"
          end
          config['HostConfig']['UsernsMode'] = 'host'
        end

        runner_container = run_container(config)
        state[:runner_container] = runner_container.json
      end

      def start_data_container(state)
        debug "driver - creating #{data_container_name}"
        config = {
          "name" => data_container_name,
          # locally built image, must use short-name
          "Image" => short_image_path(data_image),
          "HostConfig" => {
            "PortBindings" => port_bindings,
            "PublishAllPorts" => true,
            "NetworkMode" => "bridge",
          },
          "NetworkingConfig" => {
            "EndpointsConfig" => {
              self[:network_mode] => {
                "Aliases" => Array(self[:hostname]),
              },
            },
          },
        }
        data_container = run_container(config)
        state[:data_container] = data_container.json
      end

      def make_dokken_network
        lockfile = Lockfile.new "#{home_dir}/.dokken-network.lock"
        begin
          lockfile.lock
          with_retries { ::Docker::Network.get("dokken", {}, docker_connection) }
        rescue ::Docker::Error::NotFoundError
          begin
            with_retries { ::Docker::Network.create("dokken", network_settings) }
          rescue ::Docker::Error => e
            debug "driver - error :#{e}:"
          end
        ensure
          lockfile.unlock
        end
      end

      def make_data_image
        debug "driver - calling create_data_image"
        create_data_image(config[:docker_registry])
      end

      def create_chef_container(state)
        lockfile = Lockfile.new "#{home_dir}/.dokken-#{chef_container_name}.lock"
        begin
          lockfile.lock
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
              "Cmd" => "true",
              "Image" => registry_image_path(chef_image),
              "HostConfig" => {
                "NetworkMode" => self[:network_mode],
              },
            }
            chef_container = create_container(config)
            state[:chef_container] = chef_container.json
          rescue ::Docker::Error, StandardError => e
            raise "driver - #{chef_container_name} failed to create #{e}"
          end
        ensure
          lockfile.unlock
        end
      end

      def authenticate!
        # No need to authenticate if the credentials are empty
        return if docker_creds.empty?

        ::Docker.authenticate! docker_creds
      end

      def docker_creds
        @docker_creds ||= if config[:creds_file]
                            JSON.parse(IO.read(config[:creds_file]))
                          else
                            {}
                          end
      end

      def docker_config_creds
        return @docker_config_creds if @docker_config_creds

        @docker_config_creds = {}
        config_file = ::File.join(::Dir.home, ".docker", "config.json")
        if ::File.exist?(config_file)
          JSON.load_file!(config_file)["auths"].each do |k, v|
            next if v["auth"].nil?

            username, password = Base64.decode64(v["auth"]).split(":")
            @docker_config_creds[k] = { serveraddress: k, username: username, password: password }
          end
        else
          debug("~/.docker/config.json does not exist")
        end

        @docker_config_creds
      end

      def docker_creds_for_image(image)
        return docker_creds if config[:creds_file]

        image_registry = image.split("/").first

        # NOTE: Try to use DockerHub auth if exact registry match isn't found
        default_registry = "https://index.docker.io/v1/"
        if docker_config_creds.key?(image_registry)
          docker_config_creds[image_registry]
        elsif docker_config_creds.key?(default_registry)
          docker_config_creds[default_registry]
        end
      end

      def pull_platform_image
        debug "driver - pulling #{short_image_path(platform_image)}"
        config[:pull_platform_image] ? pull_image(platform_image) : pull_if_missing(platform_image)
      end

      def pull_chef_image
        debug "driver - pulling #{short_image_path(chef_image)}"
        config[:pull_chef_image] ? pull_image(chef_image) : pull_if_missing(chef_image)
      end

      def delete_image(name)
        with_retries { @image = ::Docker::Image.get(name, { "platform" => config[:platform] }, docker_connection) }
        with_retries { @image.remove(force: true) }
      rescue ::Docker::Error
        puts "Image #{name} not found. Nothing to delete."
      end

      def container_exist?(name)
        return true if ::Docker::Container.get(name, {}, docker_connection)
      rescue StandardError, ::Docker::Error::NotFoundError
        false
      end

      def parse_image_name(image)
        parts = image.split(":")

        if parts.size > 2
          tag = parts.pop
          repo = parts.join(":")
        else
          tag = parts[1] || "latest"
          repo = parts[0]
        end

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

      def create_container(args)
        with_retries { @container = ::Docker::Container.get(args["name"], {}, docker_connection) }
      rescue
        with_retries do
          args["Env"] = [] if args["Env"].nil?
          args["Env"] << "TEST_KITCHEN=1"
          args["Env"] << "CI=#{ENV["CI"]}" if ENV.include? "CI"
          args["Platform"] = config[:platform]
          info "Creating container #{args["name"]}"
          debug "driver - create_container args #{args}"
          with_retries do
            @container = ::Docker::Container.create(args.clone, docker_connection)
          rescue ::Docker::Error::ConflictError
            debug "driver - rescue ConflictError: #{args["name"]}"
            with_retries { @container = ::Docker::Container.get(args["name"], {}, docker_connection) }
          end
        rescue ::Docker::Error => e
          debug "driver - error :#{e}:"
          raise "driver - failed to create_container #{args["name"]}"
        end
      end

      def run_container(args)
        create_container(args)
        with_retries do
          @container.start
          @container = ::Docker::Container.get(args["name"], {}, docker_connection)
          wait_running_state(args["name"], true)
        end
        @container
      end

      def container_state
        @container ? @container.info["State"] : {}
      end

      def stop_container(name)
        with_retries { @container = ::Docker::Container.get(name, {}, docker_connection) }
        with_retries do
          @container.stop(force: false)
          wait_running_state(name, false)
        end
      rescue ::Docker::Error::NotFoundError
        debug "Container #{name} not found. Nothing to stop."
      end

      def delete_container(name)
        with_retries { @container = ::Docker::Container.get(name, {}, docker_connection) }
        with_retries { @container.delete(force: true, v: true) }
      rescue ::Docker::Error::NotFoundError
        debug "Container #{name} not found. Nothing to delete."
      end

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

      def chef_container_name
        config[:platform] != "" ? "chef-#{chef_version}-" + config[:platform].sub("/", "-") : "chef-#{chef_version}"
      end

      def chef_image
        "#{config[:chef_image]}:#{chef_version}"
      end

      def chef_version
        return "latest" if config[:chef_version] == "stable"

        config[:chef_version]
      end

      def data_container_name
        "#{instance_name}-data"
      end

      def data_image
        config[:data_image]
      end

      def platform_image
        config[:image] || platform_image_from_name
      end

      def platform_image_from_name
        platform, release = instance.platform.name.split("-")
        release ? [platform, release].join(":") : platform
      end

      def pull_if_missing(image)
        return if ::Docker::Image.exist?(registry_image_path(image), { "platform" => config[:platform] }, docker_connection)

        pull_image image
      end

      # https://github.com/docker/docker/blob/4fcb9ac40ce33c4d6e08d5669af6be5e076e2574/registry/auth.go#L231
      def parse_registry_host(val)
        val.sub(%r{https?://}, "").split("/").first
      end

      def pull_image(image)
        path = registry_image_path(image)
        with_retries do
          if Docker::Image.exist?(path, { "platform" => config[:platform] }, docker_connection)
            original_image = Docker::Image.get(path, { "platform" => config[:platform] }, docker_connection)
          end

          new_image = Docker::Image.create({ "fromImage" => path, "platform" => config[:platform] }, docker_creds_for_image(image), docker_connection)

          !(original_image&.id&.start_with?(new_image.id))
        end
      end

      def runner_container_name
        instance_name.to_s
      end

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
