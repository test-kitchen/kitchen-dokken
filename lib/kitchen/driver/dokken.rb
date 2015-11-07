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
      default_config :pid_one_command, 'sleep 9000'

      # (see Base#create)
      def create(state)
        # image to config
        pull_platform_image

        # chef
        pull_chef_image
        start_chef_container state

        # kitchen_cache
        make_kitchen_cache_image
        start_kitchen_cache_container state

        # work image
        build_work_image state

        # runner
        start_runner_container state

        # misc
        save_misc_state state
      end

      def destroy(_state)
        delete_kitchen_cache
        delete_chef_container
        delete_runner
        delete_work_image
      end

      private

      def delete_work_image
        return unless Docker::Image.exist?(work_image)
        i = Docker::Image.get(work_image)
        i.remove(force: true)
      end

      def build_work_image(state)
        return if Docker::Image.exist?(work_image)

        FileUtils.mkdir_p context_root
        File.write("#{context_root}/Dockerfile", work_image_dockerfile)

        i = Docker::Image.build_from_dir(context_root, 'nocache' => true, 'rm' => true)
        i.tag('repo' => repo(work_image), 'tag' => tag(work_image), 'force' => true)
        state[:work_image] = work_image
      end

      def context_root
        tmpdir = Dir.tmpdir
        "#{tmpdir}/dokken/#{instance_name}"
      end

      def work_image_dockerfile
        from = "FROM #{platform_image}"
        custom = []
        Array(config[:intermediate_instructions]).each { |c| custom << c }
        [from, custom].join("\n")
      end

      def save_misc_state(state)
        state[:platform_image] = platform_image
        state[:instance_name] = instance_name
        state[:instance_platform_name] = instance_platform_name
      end

      def instance_name
        instance.name
      end

      def instance_platform_name
        instance.platform.name
      end

      def work_image
        return "#{image_prefix}/#{instance_name}" unless image_prefix.nil?
        instance_name
      end

      def image_prefix
        'someara'
      end

      def delete_runner
        debug "driver - deleting container #{runner_container_name}"
        delete_container runner_container_name
      end

      def delete_chef_container
        debug "driver - deleting container #{chef_container_name}"
        delete_container chef_container_name
      end

      def delete_kitchen_cache
        debug "driver - deleting container #{kitchen_cache_container_name}"
        delete_container kitchen_cache_container_name
      end

      def start_runner_container(state)
        debug "driver - starting #{runner_container_name}"
        runner_container = run_container(
          'name' => runner_container_name,
          'Cmd' => Shellwords.shellwords(config[:pid_one_command]),
          'Image' => "#{repo(work_image)}:#{tag(work_image)}",
          'VolumesFrom' => [chef_container_name, kitchen_cache_container_name]
        )
        state[:runner_container] = runner_container.json
      end

      def start_kitchen_cache_container(state)
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
      end

      def make_kitchen_cache_image
        debug "driver - pulling #{kitchen_cache_image}"
        pull_if_missing kitchen_cache_image
        # -- or --
        # debug 'driver - calling create_kitchen_cache_image'
        # create_kitchen_cache_image
      end

      def start_chef_container(state)
        debug "driver - creating volume container #{chef_container_name} from #{chef_image}"
        chef_container = create_container(
          'name' => chef_container_name,
          'Cmd' => 'true',
          'Image' => "#{repo(chef_image)}:#{tag(chef_image)}"
        )
        state[:chef_container] = chef_container.json
      end

      def pull_platform_image
        debug "driver - pulling #{chef_image} #{repo(platform_image)} #{tag(platform_image)}"
        pull_if_missing platform_image
      end

      def pull_chef_image
        debug "driver - pulling #{chef_image} #{repo(chef_image)} #{tag(chef_image)}"
        pull_if_missing chef_image
      end

      def delete_image(name)
        i = Docker::Image.get(name)
        i.remove(force: true)
      rescue Docker::Error => e
        puts "Image #{name} not found. Nothing to delete."
      end

      def run_container(args)
        c = create_container(args)
        tries ||= 3
        begin
          c.start
          return c
        rescue Docker::Error => e
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
        "#{instance.name}"
      end
    end
  end
end
