#
# Author:: Sean OMeara (<sean@chef.io>)
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

require 'kitchen'
require 'tmpdir'
require 'digest/sha1'
require_relative 'dokken/helpers'

include Dokken::Transport::Helpers

module Kitchen
  module Transport
    # Wrapped exception for any internally raised errors.
    #
    # @author Sean OMeara <sean@chef.io>
    class DockerExecFailed < TransportFailed; end

    # A Transport which uses Docker tricks to execute commands and
    # transfer files.
    #
    # @author Sean OMeara <sean@chef.io>
    class Dokken < Kitchen::Transport::Base
      kitchen_transport_api_version 1

      plugin_version Kitchen::VERSION

      default_config :docker_host_url, ENV['DOCKER_HOST'] || 'unix:///var/run/docker.sock'
      default_config :read_timeout, 3600
      default_config :write_timeout, 3600
      default_config :host_ip_override, false

      # (see Base#connection)
      def connection(state, &block)
        options = connection_options(config.to_hash.merge(state))

        if @connection && @connection_options == options
          reuse_connection(&block)
        else
          create_new_connection(options, &block)
        end
      end

      # @author Sean OMeara <sean@chef.io>
      class Connection < Kitchen::Transport::Dokken::Connection
        def docker_connection
          @docker_connection ||= ::Docker::Connection.new(options[:docker_host_url], options[:docker_host_options])
        end

        def execute(command)
          return if command.nil?

          with_retries { @runner = ::Docker::Container.get(instance_name, {}, docker_connection) }
          with_retries do
            o = @runner.exec(Shellwords.shellwords(command)) { |_stream, chunk| print chunk.to_s }
            @exit_code = o[2]
          end

          if @exit_code != 0
            raise Transport::DockerExecFailed,
                  "Docker Exec (#{@exit_code}) for command: [#{command}]"
          end

          # Disabling this for now.. the Docker ZFS driver won't let us
          # commit running containers.
          #
          # with_retries { @old_image = ::Docker::Image.get(work_image, {}, docker_connection) }
          # with_retries { @new_image = @runner.commit }
          # with_retries { @new_image.tag('repo' => work_image, 'tag' => 'latest', 'force' => 'true') }
          # with_retries { @old_image.remove }
        end

        def upload(locals, remote)
          if options[:host_ip_override]
            # Allow connecting to any ip/hostname to support sibling containers
            ip = options[:host_ip_override]
          elsif options[:docker_host_url] =~ /unix:/
            # we should read the proper mapped ip, since this allows us to upload the files
            ip = options[:data_container][:NetworkSettings][:Ports][:"22/tcp"][0][:HostIp]
          elsif options[:docker_host_url] =~ /tcp:/
            ip = options[:docker_host_url].split('tcp://')[1].split(':')[0]
          else
            raise Kitchen::UserError, 'docker_host_url must be tcp:// or unix://'
          end

          port = options[:data_container][:NetworkSettings][:Ports][:"22/tcp"][0][:HostPort]

          tmpdir = Dir.tmpdir
          FileUtils.mkdir_p "#{tmpdir}/dokken"
          File.write("#{tmpdir}/dokken/id_rsa", insecure_ssh_private_key)
          FileUtils.chmod(0600, "#{tmpdir}/dokken/id_rsa")

          rsync_cmd = '/usr/bin/rsync -a -e'
          rsync_cmd << ' \''
          rsync_cmd << 'ssh -2'
          rsync_cmd << " -i #{tmpdir}/dokken/id_rsa"
          rsync_cmd << ' -o CheckHostIP=no'
          rsync_cmd << ' -o Compression=no'
          rsync_cmd << ' -o PasswordAuthentication=no'
          rsync_cmd << ' -o StrictHostKeyChecking=no'
          rsync_cmd << ' -o UserKnownHostsFile=/dev/null'
          rsync_cmd << ' -o LogLevel=ERROR'
          rsync_cmd << " -p #{port}"
          rsync_cmd << '\''
          rsync_cmd << " #{locals.join(' ')} root@#{ip}:#{remote}"
          system(rsync_cmd)
        end

        def login_command
          @runner = options[:instance_name].to_s
          args = ['exec', '-it', @runner, '/bin/bash', '-login', '-i']
          LoginCommand.new('docker', args)
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

      private

      # Builds the hash of options needed by the Connection object on
      # construction.
      #
      # @param data [Hash] merged configuration and mutable state data
      # @return [Hash] hash of connection options
      # @api private
      def connection_options(data) # rubocop:disable Metrics/MethodLength
        opts = {}
        opts[:host_ip_override] = config[:host_ip_override]
        opts[:docker_host_url] = config[:docker_host_url]
        opts[:docker_host_options] = ::Docker.options
        opts[:data_container] = data[:data_container]
        opts[:instance_name] = data[:instance_name]
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
