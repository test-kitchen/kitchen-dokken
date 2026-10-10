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

require "kitchen"
require "net/scp"
require "tmpdir" unless defined?(Dir.mktmpdir)
require "digest/sha1" unless defined?(Digest::SHA1)
require "open3" unless defined?(Open3)
require "shellwords" unless defined?(Shellwords)
require_relative "../helpers"
require_relative "../driver/dokken_version"

include Dokken::Helpers

module Kitchen
  # @see Kitchen::Transport::Dokken
  module Transport
    # Wrapped exception for any internally raised errors.
    #
    # @author Sean OMeara <sean@sean.io>
    class DockerExecFailed < TransportFailed; end

    # A Transport which uses Docker tricks to execute commands and
    # transfer files.
    #
    # Commands run through `docker exec` against the runner container. File
    # transfer only happens when the daemon cannot read the host filesystem;
    # then the files go over ssh into the data container, which shares its
    # volumes with the runner.
    #
    # @author Sean OMeara <sean@sean.io>
    class Dokken < Kitchen::Transport::Base
      kitchen_transport_api_version 2

      # kitchen-dokken's own version. Kitchen::VERSION is test-kitchen's,
      # so `kitchen diagnose` reported the framework version as the
      # plugin version for every dokken plugin.
      plugin_version Kitchen::Driver::DOKKEN_VERSION

      default_config :docker_info do |transport|
        docker_info(transport[:docker_host_url])
      end
      default_config :docker_host_url, default_docker_host
      default_config :read_timeout, 3600
      default_config :write_timeout, 3600
      default_config :login_command, "docker"
      default_config :host_ip_override do |transport|
        if transport.running_inside_docker_desktop?
          "host.docker.internal"
        elsif transport.docker_for_mac_or_win?
          "localhost"
        else
          false
        end
      end

      # (see Base#connection)
      #
      # @param state [Hash] mutable instance state
      # @yieldparam connection [Connection] the connection, if a block is given
      # @return [Connection] a connection to the runner container
      def connection(state, &block)
        options = connection_options(config.to_hash.merge(state))

        if @connection && @connection_options == options
          reuse_connection(&block)
        else
          create_new_connection(options, &block)
        end
      end

      # A connection to one runner container.
      #
      # @author Sean OMeara <sean@sean.io>
      class Connection < Kitchen::Transport::Base::Connection
        # Where rsync is expected to live. Kept as a constant so the
        # availability check and the command line cannot drift apart.
        RSYNC_PATH = "/usr/bin/rsync".freeze

        # The docker-api connection this transport talks to.
        #
        # @return [::Docker::Connection] a memoised connection
        def docker_connection
          @docker_connection ||= ::Docker::Connection.new(options[:docker_host_url], options[:docker_host_options])
        end

        # Run a command inside the runner container.
        #
        # @param command [String, nil] the command to run; nil is a no-op
        # @return [void]
        # @raise [Kitchen::Transport::DockerExecFailed] on a non-zero exit
        def execute(command)
          return if command.nil?

          with_retries { @runner = ::Docker::Container.get(instance_name, {}, docker_connection) }
          with_retries do
            o = @runner.exec(Shellwords.shellwords(command), wait: options[:timeout], "e" => { "TERM" => "xterm" }) do |_stream, chunk|
              logger << chunk
            end
            @exit_code = o[2]
          end

          raise Transport::DockerExecFailed.new("Docker Exec (#{@exit_code}) for command: [#{command}]", @exit_code) if @exit_code != 0
        end

        # Copy the kitchen sandbox into the data container.
        #
        # @param locals [Array<String>] local paths to copy
        # @param remote [String] the destination path inside the container
        # @return [void]
        # @raise [Kitchen::UserError] if docker_host_url is not tcp:// or unix://
        # @raise [Kitchen::Transport::TransportFailed] if the copy fails
        def upload(locals, remote)
          # Every route through ssh_endpoint reads the data container out of
          # state, so being handed none is not a transfer that fails -- it is
          # a caller that should not have asked. Said plainly here rather than
          # as `undefined method '[]' for nil` from three frames down.
          if options[:data_container].nil?
            raise Kitchen::Transport::TransportFailed,
              "Cannot upload to #{options[:instance_name]}: no data container was created " \
              "for this instance. Files are only shipped over ssh when the docker daemon " \
              "cannot read the local filesystem; otherwise the sandbox is bind-mounted."
          end

          ssh_ip, ssh_port = ssh_endpoint

          debug "ssh_ip : #{ssh_ip}"
          debug "ssh_port : #{ssh_port}"

          upload_files(locals, remote, ssh_ip, ssh_port, write_insecure_key)
        end

        private

        # Work out which address and port the data container's sshd can
        # actually be reached on from where kitchen is running.
        #
        # @return [Array(String, String)] the address and port to ssh to
        # @raise [Kitchen::UserError] if docker_host_url is not tcp:// or unix://
        # @api private
        def ssh_endpoint
          if options[:host_ip_override]
            # Allow connecting to any ip/hostname to support sibling containers
            [options[:host_ip_override], published_ssh_port]
          elsif /unix:/.match?(options[:docker_host_url])
            unix_ssh_endpoint
          elsif /tcp:/.match?(options[:docker_host_url])
            tcp_ssh_endpoint
          else
            raise Kitchen::UserError, "docker_host_url must be tcp:// or unix://"
          end
        end

        # The host port the data container's sshd is published on.
        #
        # @return [String] the published port
        # @api private
        def published_ssh_port
          ssh_port_binding[:HostPort]
        end

        # The first host binding for the data container's ssh port.
        #
        # @return [Hash] the `22/tcp` port binding
        # @api private
        def ssh_port_binding
          options[:data_container][:NetworkSettings][:Ports][:"22/tcp"][0]
        end

        # Pick an endpoint for a daemon reached over a unix socket.
        #
        # When sshd is published on every interface we can talk to the
        # container's own address directly; otherwise we have to go through
        # the specific host mapping the daemon set up.
        #
        # @return [Array(String, String)] the address and port to ssh to
        # @api private
        def unix_ssh_endpoint
          if ssh_port_binding[:HostIp] == "0.0.0.0"
            [data_container_ip, "22"]
          else
            # we should read the proper mapped ip, since this allows us to upload the files
            [ssh_port_binding[:HostIp], ssh_port_binding[:HostPort]]
          end
        end

        # The data container's own address on the docker network.
        #
        # NetworkSettings.IPAddress is only populated for the default bridge.
        # The data container is handed a NetworkingConfig endpoint whenever
        # network_mode names a user-defined network -- which dokken's own
        # default does -- and its address then lives under
        # NetworkSettings.Networks.<name>, leaving the legacy field empty.
        # Uploading to that empty value produced `root@:/opt/kitchen` and an
        # unresolvable hostname.
        #
        # @return [String] the container's address
        # @raise [Kitchen::Transport::TransportFailed] if the daemon reported none
        # @api private
        def data_container_ip
          settings = options[:data_container][:NetworkSettings]

          legacy = settings[:IPAddress].to_s
          return legacy unless legacy.empty?

          (settings[:Networks] || {}).each_value do |network|
            address = network[:IPAddress].to_s
            return address unless address.empty?
          end

          raise Kitchen::Transport::TransportFailed,
            "The data container has no address on any docker network: #{settings[:Networks].inspect}"
        end

        # Every address the data container has, best candidate first.
        #
        # A user-defined network comes before the default bridge. That order
        # matters when kitchen is itself a container: a sibling on the dokken
        # network can reach the container there but has no route to its
        # bridge address, and preferring the bridge would send every upload
        # to the docker host instead.
        #
        # The legacy top-level `IPAddress` is the default bridge's, so it
        # sorts with the bridge and is deduplicated against it.
        #
        # @return [Array<String>] addresses, most specific network first
        # @api private
        def data_container_addresses
          settings = options[:data_container][:NetworkSettings]
          networks = settings[:Networks] || {}

          user_defined, default_bridge = networks.partition { |name, _| name.to_s != "bridge" }

          addresses = (user_defined + default_bridge).map { |_, network| network[:IPAddress].to_s }
          addresses << settings[:IPAddress].to_s

          addresses.reject(&:empty?).uniq
        end

        # Pick an endpoint for a daemon reached over tcp.
        #
        # The container's address on the dokken network is preferred, since it
        # avoids a round trip through the host, but it is only usable when
        # kitchen shares a route with the daemon. Fall back to the docker host
        # itself when neither candidate port answers.
        #
        # @return [Array(String, String)] the address and port to ssh to
        # @api private
        def tcp_ssh_endpoint
          # DOCKER_HOST
          docker_host_url_ip = options[:docker_host_url].split("tcp://")[1].split(":")[0]

          # mapped port
          candidate_ssh_port = published_ssh_port

          # The addresses come from the state the driver recorded after it
          # started the container. This used to ask the daemon instead --
          # Docker::Container.all, find ours by name, then read
          # Networks["dokken"]["IPAddress"] -- which was wrong twice over.
          #
          # Container.all lists only *running* containers, so a data container
          # that had exited made `find` return nil and the chained `.info`
          # raise `undefined method 'info' for nil`. And the dokken network is
          # only attached when network_mode is left at its default:
          # start_data_container adds the endpoint
          # "unless %w{host bridge}.include?" and names it after network_mode,
          # so `bridge`, `host` and every custom network name produced
          # `undefined method '[]' for nil` on a remote daemon.
          data_container_addresses.each do |candidate_ip|
            debug "candidate_ip - #{candidate_ip}"
            debug "candidate_ssh_port - #{candidate_ssh_port}"

            if port_open?(candidate_ip, candidate_ssh_port)
              debug "candidate_ip - #{candidate_ip}/#{candidate_ssh_port} open"
              return [candidate_ip, candidate_ssh_port]
            elsif port_open?(candidate_ip, "22")
              debug "candidate_ip - #{candidate_ip}/22 open"
              return [candidate_ip, "22"]
            end
          end

          # Nothing answered, or -- with host networking -- the container has
          # no address of its own to try. The docker host is the endpoint.
          debug "no data container address answered; falling back to the docker host"
          [docker_host_url_ip, candidate_ssh_port]
        end

        # Write the built-in insecure private key somewhere ssh will accept it.
        #
        # ssh refuses to use a key file other users can read, so the file is
        # written 0600 under a per-uid directory.
        #
        # @return [String] the directory holding the `id_rsa` file
        # @api private
        def write_insecure_key
          tmpdir = Dir.tmpdir + "/dokken/"
          FileUtils.mkdir_p tmpdir.to_s, mode: 0o777
          tmpdir += Process.uid.to_s
          FileUtils.mkdir_p tmpdir.to_s
          File.write("#{tmpdir}/id_rsa", insecure_ssh_private_key)
          FileUtils.chmod(0o600, "#{tmpdir}/id_rsa")
          tmpdir
        end

        # Copy files into the data container, preferring rsync.
        #
        # @param locals [Array<String>] local paths to copy
        # @param remote [String] the destination path inside the container
        # @param ssh_ip [String] the address to ssh to
        # @param ssh_port [String] the port to ssh to
        # @param key_dir [String] directory holding the `id_rsa` file
        # @return [void]
        # @api private
        def upload_files(locals, remote, ssh_ip, ssh_port, key_dir)
          if rsync_available?
            upload_via_rsync(locals, remote, ssh_ip, ssh_port, key_dir)
          else
            debug "Rsync is not installed at #{RSYNC_PATH}. Falling back to SCP."
            upload_via_scp(locals, remote, ssh_ip, ssh_port, key_dir)
          end
        end

        # Whether rsync is installed where we expect it.
        #
        # This is checked up front rather than inferred from a failed shell
        # invocation: backticks run the command through /bin/sh, which reports
        # a missing binary as exit status 127 and never raises Errno::ENOENT,
        # so an exception-based check could never see it.
        #
        # @return [Boolean] true when rsync can be executed
        # @api private
        def rsync_available?
          File.executable?(RSYNC_PATH)
        end

        # Build the rsync invocation used to copy the sandbox in.
        #
        # Returned as an argv array, not a command line, so that
        # {#upload_via_rsync} can spawn rsync directly instead of through
        # /bin/sh. The paths here are the kitchen and verifier sandboxes,
        # which live under the user's home directory -- and a home directory
        # containing a space is ordinary on macOS and Windows. Interpolated
        # into a shell string it split into two arguments, and rsync failed
        # with "No such file or directory" naming half a path. A quote or a
        # `$` in the path was worse: the shell acted on it.
        #
        # @param locals [Array<String>] local paths to copy
        # @param remote [String] the destination path inside the container
        # @param ssh_ip [String] the address to ssh to
        # @param ssh_port [String] the port to ssh to
        # @param key_dir [String] directory holding the `id_rsa` file
        # @return [Array<String>] an argv array
        # @api private
        def rsync_command(locals, remote, ssh_ip, ssh_port, key_dir)
          # rsync word-splits the -e value itself, so this one stays a
          # string. It carries no user-supplied path: key_dir is built by
          # {#write_insecure_key} under Dir.tmpdir, and ssh_port comes from
          # the daemon's own port bindings.
          ssh_opts = [
            "ssh -2",
            "-i #{key_dir}/id_rsa",
            "-o CheckHostIP=no",
            "-o Compression=no",
            "-o PasswordAuthentication=no",
            "-o StrictHostKeyChecking=no",
            "-o UserKnownHostsFile=/dev/null",
            "-o LogLevel=ERROR",
            "-p #{ssh_port}",
          ].join(" ")

          [RSYNC_PATH, "-a", "-e", ssh_opts, *locals, "root@#{ssh_ip}:#{remote}"]
        end

        # Copy files in with rsync.
        #
        # A non-zero exit is raised rather than ignored: silently continuing
        # leaves the converge running against a container with no cookbooks in
        # it, which then fails much further along with a confusing error.
        #
        # @param locals [Array<String>] local paths to copy
        # @param remote [String] the destination path inside the container
        # @param ssh_ip [String] the address to ssh to
        # @param ssh_port [String] the port to ssh to
        # @param key_dir [String] directory holding the `id_rsa` file
        # @return [void]
        # @raise [Kitchen::Transport::TransportFailed] if rsync exits non-zero
        # @api private
        def upload_via_rsync(locals, remote, ssh_ip, ssh_port, key_dir)
          cmd = rsync_command(locals, remote, ssh_ip, ssh_port, key_dir)
          debug "rsync_cmd :#{cmd.inspect}:"

          # Splatted, so Open3 execs rsync directly. Handing it one joined
          # string would put /bin/sh back in the path and undo the quoting
          # this argv exists to avoid.
          output, status = Open3.capture2e(*cmd)
          return if status.success?

          raise Kitchen::Transport::TransportFailed.new(
            "rsync exited #{status.exitstatus} while uploading to #{ssh_ip}:#{remote}: #{output.strip}",
            status.exitstatus
          )
        end

        # Copy files in with scp, for hosts without rsync.
        #
        # @param locals [Array<String>] local paths to copy
        # @param remote [String] the destination path inside the container
        # @param ssh_ip [String] the address to ssh to
        # @param ssh_port [String] the port to ssh to
        # @param key_dir [String] directory holding the `id_rsa` file
        # @return [void]
        # @api private
        def upload_via_scp(locals, remote, ssh_ip, ssh_port, key_dir)
          locals.each do |local|
            Net::SCP.upload!(ssh_ip,
              "root",
              local,
              remote,
              recursive: true,
              ssh: { port: ssh_port, keys: ["#{key_dir}/id_rsa"] })
          end
        end

        public

        # Build the command `kitchen login` runs to drop the user into the
        # runner container.
        #
        # `tput` reports the terminal size with a trailing newline; that has to
        # be stripped, or bash reads the embedded newline in COLUMNS as the
        # start of another command line.
        #
        # @return [Kitchen::LoginCommand] the command to exec
        def login_command
          @runner = options[:instance_name].to_s
          cols = `tput cols`.strip
          lines = `tput lines`.strip
          args = ["exec", "-e", "COLUMNS=#{cols}", "-e", "LINES=#{lines}", "-it", @runner, "/bin/bash", "-login", "-i"]
          LoginCommand.new(options[:login_command], args)
        end

        private

        # The runner container's name.
        #
        # @return [String] the container name
        # @api private
        def instance_name
          options[:instance_name]
        end

        # The locally built image the runner was created from.
        #
        # @return [String] an image reference
        # @api private
        def work_image
          return "#{image_prefix}/#{instance_name}" unless image_prefix.nil?

          instance_name
        end

        # The configured image name prefix, if any.
        #
        # @return [String, nil] the prefix
        # @api private
        def image_prefix
          options[:image_prefix]
        end

        # Retry a docker API call through the errors that retrying can fix.
        #
        # @yield the API call to attempt
        # @return [Object] the block's value
        # @raise [::Docker::Error::DockerError] if every attempt failed
        # @api private
        def with_retries
          tries = 20
          begin
            yield
            # Only catch errors that can be fixed with retries.
          rescue ::Docker::Error::ServerError, # 404
                 ::Docker::Error::UnexpectedResponseError, # 400
                 ::Docker::Error::TimeoutError,
                 ::Docker::Error::IOError => e
            tries -= 1
            retry if tries > 0
            raise e
          end
        end
      end

      # Detect whether or not we are running in Docker for Mac or Windows
      #
      # @return [TrueClass,FalseClass]
      def docker_for_mac_or_win?
        ::Docker.info(::Docker::Connection.new(config[:docker_host_url], {}))["Name"] == "docker-desktop"
      # `::StandardError`, spelled out. This method lives inside module
      # Kitchen, where a bare `StandardError` resolves to
      # Kitchen::StandardError -- which Excon::Error::Socket is not, so an
      # unreachable daemon would escape instead of answering "no".
      rescue ::StandardError
        false
      end

      private

      # Builds the hash of options needed by the Connection object on
      # construction.
      #
      # @param data [Hash] merged configuration and mutable state data
      # @return [Hash] hash of connection options
      # @api private
      def connection_options(data)
        opts = {}
        opts[:logger] = logger
        opts[:host_ip_override] = config[:host_ip_override]
        opts[:docker_host_url] = config[:docker_host_url]
        opts[:docker_host_options] = ::Docker.options
        opts[:data_container] = data[:data_container]
        opts[:instance_name] = data[:instance_name]
        opts[:timeout] = data[:write_timeout]
        opts[:login_command] = data[:login_command]
        opts
      end

      # Creates a new Dokken Connection instance and save it for potential future
      # reuse.
      #
      # @param options [Hash] connection options
      # @return [Ssh::Connection] an SSH Connection instance
      # @api private
      def create_new_connection(options, &block)
        if @connection
          logger.debug("[Dokken] shutting previous connection #{@connection}")
          @connection.close
        end

        @connection_options = options
        @connection = Kitchen::Transport::Dokken::Connection.new(options, &block)
      end

      # Return the last saved Dokken connection instance.
      #
      # @return [Dokken::Connection] an Dokken Connection instance
      # @api private
      def reuse_connection
        logger.debug("[Dokken] reusing existing connection #{@connection}")
        yield @connection if block_given?
        @connection
      end
    end
  end
end
