# -*- encoding: utf-8 -*-
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
require 'kitchen/provisioner/chef_zero'

module Kitchen
  module Provisioner
    # @author Sean OMeara <sean@chef.io>
    class Dokken < Kitchen::Provisioner::ChefZero
      kitchen_provisioner_api_version 2

      plugin_version Kitchen::VERSION

      default_config :root_path, '/opt/kitchen'

      # (see Base#call)
      def call(state)
        create_sandbox
        sandbox_dirs = Dir.glob(File.join(sandbox_path, '*'))

        instance.transport.connection(state) do |conn|
          info("Transferring files to #{instance.to_str}")
          conn.upload(sandbox_dirs, config[:root_path])
          debug('Transfer complete')
          conn.execute(run_command)
        end
      rescue Kitchen::Transport::TransportFailed => ex
        raise ActionFailed, ex.message
      ensure
        cleanup_sandbox
      end

      private

      # magic method name because we're subclassing ChefZero
      def run_command
        cmd = '/opt/chef/embedded/bin/chef-client'
        cmd << ' -z'
        cmd << ' -c /opt/kitchen/client.rb'
        cmd << ' -j /opt/kitchen/dna.json'
        cmd << ' -l warn'
        cmd << ' -F doc'
      end

      def runner_container_name
        instance.name.to_s
      end
    end
  end
end
