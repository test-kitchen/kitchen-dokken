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

Excon.defaults[:ssl_verify_peer] = false

module Kitchen
  module Driver
    # Dokken driver for Kitchen.
    #
    # @author Sean OMeara <sean@chef.io>
    class Dokken < Kitchen::Driver::Base
      include DokkenHelpers

      def create(state)
        @repotags = []
        Docker::Image.all.each { |i| @repotags << i.info['RepoTags'] }

        @chef_container = nil
        @kitchen_container = nil
        @runner_container = nil

        # Make sure Chef container is running
        pull_if_missing('someara/chef', 'latest')
        @chef_container = run_if_missing(
          "chef",
          'Cmd' => 'true',
          'Image' => 'someara/chef',
          'Tag' => 'latest'
          )
        state[:chef_container] = @chef_container

        # Create a temporary cache container
        pull_if_missing('someara/kitchen-cache', 'latest')
        @kitchen_container = run_if_missing(
          "kitchen_sandbox",
          'Cmd' => 'true',
          'Image' => 'someara/kitchen-cache',
          'Tag' => 'latest'
          )
        state[:kitchen_container] = @kitchen_container

        # Start the suite container
        pull_if_missing(instance.platform.name, 'latest')
        @runner_container = run_if_missing(
          "#{instance.name}-chef_runner",
          'Cmd' => [
            '/opt/chef/embedded/bin/chef-client', '-z',
            '-c', '/tmp/kitchen/client.rb',
            '-k', '/tmp/kitchen/dna.json',
            '-F', 'doc'
          ],
          'Image' => 'someara/kitchen-cache',
          'Tag' => 'latest',
          'VolumesFrom' => [ 'chef', 'kitchen_sandbox' ]
          )
        state[:runner_container] = @runner_container
      end

      def destroy(_state)
        # require 'pry'; binding.pry
        destroy_if_running "#{instance.name}-chef_runner"
      end
    end
  end
end
