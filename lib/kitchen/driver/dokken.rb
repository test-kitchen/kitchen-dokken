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

# FIXME: - make true
Excon.defaults[:ssl_verify_peer] = true

module Kitchen
  module Driver
    # Dokken driver for Kitchen.
    #
    # @author Sean OMeara <sean@chef.io>
    class Dokken < Kitchen::Driver::Base

      def delete_container(name)
        c = Docker::Container.get(name)
        puts "destroying container #{name}"
        c.stop
        c.remove
      rescue
        puts "container #{name} not found"
      end

      # container
      def container_created?(container_name)
        Docker::Container.get(container_name)
        return true
      rescue Docker::Error::NotFoundError
        return false
      end

      def create_container(args)
        begin
          c = Docker::Container.get(args['name'])
          return c
        rescue Docker::Error::NotFoundError
          begin
            tries ||= 3
            c = Docker::Container.create(args)
            return c
          rescue Docker::Error => e
            retry unless (tries -= 1).zero?
            raise e.message
          end
        end
      end
          
      def run_container(args)
        c = create_container(args)
        tries ||= 3
        begin
          c.start
          return c
        rescue
          retry unless (tries -= 1).zero?
          raise e.message
        end
      end

      # pull
      def pull_image(repo, tag)
        retries ||= 3
        Docker::Image.create(
          'fromImage' => repo,
          'tag' => tag
          )
      rescue Docker::Error => e
        retry unless (tries -= 1).zero?
        raise e.message
      end

      def pull_if_missing(repo, tag)
        return if Docker::Image.exist?("#{repo}:#{tag}")
        pull_image(repo, tag)
      end

      # (see Base#create)
      def create(state)
        # pull images
        pull_if_missing('someara/chef', 'latest')
        pull_if_missing('someara/kitchen-cache', 'latest')
        pull_if_missing(instance.platform.name, 'latest')

        # chef container
        chef_container = create_container(
          'name' => "chef-#{instance.name}",
          'Cmd' => 'true',
          'Image' => 'someara/chef',
          'Tag' => 'latest'
        )
        state[:chef_container] = chef_container.json

        # kitchen cache
        kitchen_container = run_container(
          'name' => "kitchen_cache-#{instance.name}",
          'Image' => 'someara/kitchen-cache',
          'Tag' => 'latest',
          'PortBindings' => {
            '22/tcp' => [
              { 'HostPort' => '' }]
          },
          'PublishAllPorts' => true
        )
        state[:kitchen_container] = kitchen_container.json

        # platform to test
        state[:instance_name] = instance.name
        state[:instance_platform_name] = instance.platform.name
      end

      def destroy(_state)
        delete_container "chef_runner-#{instance.name}"
        delete_container "kitchen_cache-#{instance.name}"
        delete_container "chef-#{instance.name}"

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
