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

    class Dokken < Kitchen::Transport::Base
      kitchen_transport_api_version 1

      plugin_version Kitchen::VERSION

      def connection(state, &block)
        options = config.to_hash.merge(state)
        Kitchen::Transport::Dokken::Connection.new(options, &block)
      end

      class Connection < Kitchen::Transport::Dokken::Connection
        
        def execute(command)
          return if command.nil?
          
          c = Docker::Container.get("#{options[:instance_name]}-runner")
          o = c.exec(Shellwords.shellwords(command)) { |stream, chunk| puts "#{stream}: #{chunk}" }
          # require 'pry' ; binding.pry
          exit_code = o[2]

          if exit_code != 0
            raise Transport::DockerExecFailed,
            "Docker Exec (#{exit_code}) for command: [#{command}]"
          end
        end

        def upload(locals, remote)
          ip = ENV['DOCKER_HOST'].split('tcp://')[1].split(':')[0]
          port = options[:kitchen_container][:NetworkSettings][:Ports][:"22/tcp"][0][:HostPort]

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
      end
    end
  end
end
