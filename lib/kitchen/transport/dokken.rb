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
require 'digest/sha1'
require_relative 'dokken/helpers'

include Dokken::Transport::Helpers

module Kitchen
  module Transport
    # Wrapped exception for any internally raised errors.
    #
    # @author Sean OMeara <sean@chef.io>
    class DokkenFailed < TransportFailed; end

    class Dokken < Kitchen::Transport::Base
      kitchen_transport_api_version 1

      plugin_version Kitchen::VERSION

      def connection(state, &block)
        options = config.to_hash.merge(state)
        Kitchen::Transport::Dokken::Connection.new(options, &block)
      end

      class Connection < Kitchen::Transport::Dokken::Connection
        def execute(command)
          # system("docker exec #{options[:instance_name]}-runner #{command}") unless command.nil?
          logger << `docker exec #{options[:instance_name]}-runner #{command}` unless command.nil?
        end

        def upload(locals, remote)
          ip = ENV['DOCKER_HOST'].split('tcp://')[1].split(':')[0]
          port = options[:kitchen_container][:NetworkSettings][:Ports][:"22/tcp"][0][:HostPort]

          # require 'pry' ; binding.pry
          # tmpdir = Dir.tmpdir
          # FileUtils.mkdir_p "#{tmpdir}/dokken"
          # File.write("#{tmpdir}/dokken/id_rsa", insecure_ssh_private_key)

          rsync_cmd = '/usr/bin/rsync -az '
          rsync_cmd << "-e \"ssh -i #{tmpdir}/dokken/id_rsa -o StrictHostKeyChecking=no -p #{port}\""
          rsync_cmd << " #{locals.join(' ')} root@#{ip}:#{remote}"
          system(rsync_cmd)
        end
      end
    end
  end
end
