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
require 'docker'
require_relative 'dokken/helpers'

include Dokken::Driver::Helpers

# FIXME: - make true
Excon.defaults[:ssl_verify_peer] = false

module Kitchen
  module Driver
    # Dokken driver for Kitchen.
    #
    # @author Sean OMeara <sean@chef.io>
    class Dokken < Kitchen::Driver::Base
      # (see Base#create)
      def create(state)
        pull_platform_image

        # chef container
        debug "driver - pulling #{chef_image} #{repo(chef_image)} #{tag(chef_image)}"
        pull_if_missing chef_image

        debug "driver - creating volume container #{chef_container_name} from #{chef_image}"
        chef_container = create_container(
          'name' => chef_container_name,
          'Cmd' => 'true',
          'Image' => "#{repo(chef_image)}:#{tag(chef_image)}"
        )
        state[:chef_container] = chef_container.json

        # kitchen cache
        # debug "driver - pulling #{kitchen_cache_image}"
        # pull_if_missing kitchen_cache_image
        debug 'driver - calling create_kitchen_cache_image'
        create_kitchen_cache_image

        debug "driver - creating #{kitchen_cache_container_name}"
        kitchen_container = run_container(
          'name' => kitchen_cache_container_name,
          'Image' => "#{repo(kitchen_cache_image)}:#{tag(kitchen_cache_image)}",
          'PortBindings' => {
            '22/tcp' => [
              { 'HostPort' => '' }
            ]
          },
          'PublishAllPorts' => true
        )
        state[:kitchen_container] = kitchen_container.json

        # runner container
        debug "driver - starting #{runner_container_name}"
        runner_container = run_container(
          'name' => runner_container_name,
          'Cmd' => %w(sleep 9000),
          'Image' => "#{repo(platform_image)}:#{tag(platform_image)}",
          'VolumesFrom' => [chef_container_name, kitchen_cache_container_name]
        )

        state[:platform_image] = platform_image
        state[:instance_name] = instance.name
        state[:instance_platform_name] = instance.platform.name
      end

      def destroy(_state)
        debug "driver - deleting container #{kitchen_cache_container_name}"
        delete_container kitchen_cache_container_name

        debug "driver - deleting container #{chef_container_name}"
        delete_container chef_container_name

        debug "driver - deleting container #{runner_container_name}"
        delete_container runner_container_name

        # FIXME: is this still needed?
        debug "driver - deleting image someara/#{instance.name}"
        delete_image "someara/#{instance.name}"
      end

      private

      def pull_platform_image
        debug "driver - pulling #{chef_image} #{repo(platform_image)} #{tag(platform_image)}"
        pull_if_missing platform_image
      end

      def delete_image(name)
        i = Docker::Image.get(name)
        i.remove(force: true)
      rescue
        puts "Image #{name} not found. Nothing to delete."
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

      def delete_container(name)
        c = Docker::Container.get(name)
        puts "Destroying container #{name}."
        c.stop
        c.delete(force: true, v: true)
      rescue
        puts "Container #{name} not found. Nothing to delete."
      end

      def create_container(args)
        Docker::Container.get(args['name'])
      rescue
        return Docker::Container.create(args)
      end

      def repo(image)
        image.split(':')[0]
      end

      def tag(image)
        image.split(':')[1] || 'latest'
      end

      def pull_image(image)
        retries ||= 3
        # puts "SEANDEBUG: #{image}"
        # puts "SEANDEBUG: #{repo(image)} #{tag(image)}"
        Docker::Image.create('fromImage' => repo(image), 'tag' => tag(image))
      rescue Docker::Error => e
        retry unless (tries -= 1).zero?
        raise e.message
      end

      def pull_if_missing(image)
        return if Docker::Image.exist?("#{repo(image)}:#{tag(image)}")
        pull_image image
      end

      def platform_image
        config[:image]
      end

      def chef_version
        config[:chef_version]
      end

      def chef_image
        "someara/chef:#{chef_version}"
      end

      def chef_container_name
        "#{instance.name}-chef"
      end

      def kitchen_cache_image
        'someara/kitchen-cache:latest'
      end

      def kitchen_cache_container_name
        "#{instance.name}-kitchen_cache"
      end

      def runner_container_name
        "#{instance.name}-runner"
      end
    end
  end
end
