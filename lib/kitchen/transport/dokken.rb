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
require_relative "../helpers"

include Dokken::Helpers

module Kitchen
  module Transport
    # Wrapped exception for any internally raised errors.
    #
    # @author Sean OMeara <sean@sean.io>
    class DockerExecFailed < TransportFailed; end

    # A Transport which uses Docker tricks to execute commands and
    # transfer files.
    #
    # @author Sean OMeara <sean@sean.io>
    class Dokken < Kitchen::Transport::Base
      kitchen_transport_api_version 2

      plugin_version Kitchen::VERSION

      default_config :docker_info, docker_info
      default_config :docker_host_url, default_docker_host
      default_config :read_timeout, 3600
      default_config :write_timeout, 3600
      default_config :login_command, "docker"
      default_config :host_ip_override do |transport|
        transport.docker_for_mac_or_win? ? "localhost" : false
      end

      # (see Base#connection)
      def connection(state, &block)
        options = connection_options(config.to_hash.merge(state))

        if @connection && @connection_options == options
          reuse_connection(&block)
        else
          create_new_connection(options, &block)
        end
      end

      # @author Sean OMeara <sean@sean.io>
      class Connection < Kitchen::Transport::Dokken::Connection
        def docker_connection
          @docker_connection ||= ::Docker::Connection.new(options[:docker_host_url], options[:docker_host_options])
        end

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

        def upload(locals, remote)
          if options[:host_ip_override]
            # Allow connecting to any ip/hostname to support sibling containers
            ssh_ip = options[:host_ip_override]
            ssh_port = options[:data_container][:NetworkSettings][:Ports][:"22/tcp"][0][:HostPort]

          elsif /unix:/.match?(options[:docker_host_url])
            if options[:data_container][:NetworkSettings][:Ports][:"22/tcp"][0][:HostIp] == "0.0.0.0"
              ssh_ip = options[:data_container][:NetworkSettings][:IPAddress]
              ssh_port = "22"
            else
              # we should read the proper mapped ip, since this allows us to upload the files
              ssh_ip = options[:data_container][:NetworkSettings][:Ports][:"22/tcp"][0][:HostIp]
              ssh_port = options[:data_container][:NetworkSettings][:Ports][:"22/tcp"][0][:HostPort]
            end

          elsif /tcp:/.match?(options[:docker_host_url])
            name = options[:data_container][:Name]

            # DOCKER_HOST
            docker_host_url_ip = options[:docker_host_url].split("tcp://")[1].split(":")[0]

            # mapped IP of data container
            candidate_ip = ::Docker::Container.all.find do |x|
              x.info["Names"][0].eql?(name)
            end.info["NetworkSettings"]["Networks"]["dokken"]["IPAddress"]

            # mapped port
            candidate_ssh_port = options[:data_container][:NetworkSettings][:Ports][:"22/tcp"][0][:HostPort]

            debug "candidate_ip - #{candidate_ip}"
            debug "candidate_ssh_port - #{candidate_ssh_port}"

            if port_open?(candidate_ip, candidate_ssh_port)
              debug "candidate_ip - #{candidate_ip}/#{candidate_ssh_port} open"
              ssh_ip = candidate_ip
              ssh_port = candidate_ssh_port

            elsif port_open?(candidate_ip, "22")
              ssh_ip = candidate_ip
              ssh_port = "22"
              debug "candidate_ip - #{candidate_ip}/22 open"
            else
              ssh_ip = docker_host_url_ip
              ssh_port = candidate_ssh_port
            end
          else
            raise Kitchen::UserError, "docker_host_url must be tcp:// or unix://"
          end

          debug "ssh_ip : #{ssh_ip}"
          debug "ssh_port : #{ssh_port}"

          tmpdir = Dir.tmpdir + "/dokken/"
          FileUtils.mkdir_p tmpdir.to_s, mode: 0o777
          tmpdir += Process.uid.to_s
          FileUtils.mkdir_p tmpdir.to_s
          File.write("#{tmpdir}/id_rsa", insecure_ssh_private_key)
          FileUtils.chmod(0o600, "#{tmpdir}/id_rsa")

          begin
            rsync_cmd = "/usr/bin/rsync -a -e"
            rsync_cmd << " '"
            rsync_cmd << "ssh -2"
            rsync_cmd << " -i #{tmpdir}/id_rsa"
            rsync_cmd << " -o CheckHostIP=no"
            rsync_cmd << " -o Compression=no"
            rsync_cmd << " -o PasswordAuthentication=no"
            rsync_cmd << " -o StrictHostKeyChecking=no"
            rsync_cmd << " -o UserKnownHostsFile=/dev/null"
            rsync_cmd << " -o LogLevel=ERROR"
            rsync_cmd << " -p #{ssh_port}"
            rsync_cmd << "'"
            rsync_cmd << " #{locals.join(" ")} root@#{ssh_ip}:#{remote}"
            debug "rsync_cmd :#{rsync_cmd}:"
            `#{rsync_cmd}`
          rescue Errno::ENOENT
            debug "Rsync is not installed. Falling back to SCP."
            locals.each do |local|
              Net::SCP.upload!(ssh_ip,
                               "root",
                               local,
                               remote,
                               recursive: true,
                               ssh: { port: ssh_port, keys: ["#{tmpdir}/id_rsa"] })
            end
          end
        end

        def login_command
          @runner = options[:instance_name].to_s
          cols = `tput cols`
          lines = `tput lines`
          args = ["exec", "-e", "COLUMNS=#{cols}", "-e", "LINES=#{lines}", "-it", @runner, "/bin/bash", "-login", "-i"]
          LoginCommand.new(options[:login_command], args)
        end

        private

        def instance_name
          options[:instance_name]
        end

        def work_image
          return "#{image_prefix}/#{instance_name}" unless image_prefix.nil?

          instance_name
        end

        def image_prefix
          options[:image_prefix]
        end

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
        ::Docker.info(::Docker::Connection.new(config[:docker_host_url], {}))["Name"] == "moby"
      rescue
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
      # @param options [Hash] conneciton options
      # @return [Ssh::Connection] an SSH Connection instance
      # @api private
      def create_new_connection(options, &block)
        if @connection
          logger.debug("[Dokken] shutting previous connection #{@connection}")
          @connection.close
        end

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
