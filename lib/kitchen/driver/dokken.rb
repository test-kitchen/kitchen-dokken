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
require 'docker'
require_relative 'dokken/helpers.rb'

# FIXME - make true
Excon.defaults[:ssl_verify_peer] = false

module Kitchen
  module Driver
    # Dokken driver for Kitchen.
    #
    # @author Sean OMeara <sean@chef.io>
    class Dokken < Kitchen::Driver::Base
      include DokkenHelpers

      # (see Base#create)
      def create(state)
        @repotags = []
        Docker::Image.all.each { |i| @repotags << i.info['RepoTags'] }

        @chef_container = nil
        @kitchen_container = nil
        @bitmover_container = nil
        @runner_container = nil

        # Make sure Chef container is running
        pull_if_missing('someara/chef', 'latest')

        @chef_container = run_if_missing(
          'name' => "chef",
          'Cmd' => 'true',
          'Image' => 'someara/chef',
          'Tag' => 'latest'
          )
        # require 'pry'; binding.pry
        state[:chef_container] = @chef_container.json

        # Create a temporary cache container
        pull_if_missing('someara/kitchen-cache', 'latest')
        @kitchen_container = run_if_missing(
          'name' => "kitchen_cache-#{instance.name}",
          'Cmd' => 'true',
          'Image' => 'someara/kitchen-cache',
          'Tag' => 'latest'
          )
        # require 'pry'; binding.pry
        state[:kitchen_container] = @kitchen_container.json

        # Create an ssh+rsync service
        pull_if_missing('someara/kitchen2docker', 'latest')
        @bitmover_container = run_if_missing(
          'name' => "bit_mover-#{instance.name}",
          'Image' => 'someara/kitchen2docker',
          'Tag' => 'latest',
          'PortBindings' => {
            '22/tcp' => [
              { "HostPort" => "" }]
          },
          'PublishAllPorts' => true,
          'VolumesFrom' => [ "kitchen_cache-#{instance.name}"]
          )
        @bitmover_container.start
        state[:bitmover_container] = @bitmover_container.json
        
        # Start the suite container
        pull_if_missing(instance.platform.name, 'latest')
        @runner_container = run_if_missing(
          'name' => "chef_runner-#{instance.name}",
          'Cmd' => [
            '/opt/chef/embedded/bin/chef-client', '-z',
            '-c', '/tmp/kitchen/client.rb',
            '-k', '/tmp/kitchen/dna.json',
            '-F', 'doc'
          ],
          'Image' => instance.platform.name,
          'Tag' => 'latest',
          'VolumesFrom' => [ 'chef', "kitchen_cache-#{instance.name}" ]
          )
        # require 'pry'; binding.pry
        state[:runner_container] = @runner_container.json
      end

      def destroy(state)
        # require 'pry'; binding.pry
        destroy_if_running "chef_runner-#{instance.name}"
        destroy_if_running "bit_mover-#{instance.name}"
        destroy_if_running "kitchen_cache-#{instance.name}"
      end
    end
  end
end
