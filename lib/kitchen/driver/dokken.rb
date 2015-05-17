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

        # Make sure Chef container is running
        pull_if_missing('someara/chef', 'latest')
        chef_container = run_if_missing(
          'name' => 'chef',
          'Cmd' => 'true',
          'Image' => 'someara/chef',
          'Tag' => 'latest'
          )
        state[:chef_container] = chef_container.json

        # Create a temporary volume container
        # Create an ssh+rsync service
        pull_if_missing('someara/kitchen-cache', 'latest')
        kitchen_container = run_if_missing(
          'name' => "kitchen_cache-#{instance.name}",
          'Image' => 'someara/kitchen-cache',
          'Tag' => 'latest',
          'PortBindings' => {
            '22/tcp' => [
              { 'HostPort' => '' }]
          },
          'PublishAllPorts' => true,
          )
        kitchen_container.start
        state[:kitchen_container] = kitchen_container.json

        # pull runner image
        pull_if_missing(instance.platform.name, 'latest')

        # shove some information into state so we can get at it from
        # the transport
        state[:instance_name] = instance.name
        state[:instance_platform_name] = instance.platform.name
      end

      def destroy(_state)
        # require 'pry'; binding.pry
        destroy_if_running "chef_runner-#{instance.name}"
        destroy_if_running "kitchen_cache-#{instance.name}"

        begin
          work_image = Docker::Image.get("someara/#{instance.name}")
          work_image.remove
        rescue
          puts "Image someara/#{instance.name} does not exist. Nothing to do"
        end
      end
    end
  end
end
