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
      default_config :pid_one_command, 'sh -c "trap exit 0 SIGTERM; while :; do sleep 1; done"'
      default_config :privileged, false

      # (see Base#create)
      def create(state)
        # image to config
        pull_platform_image

        # chef
        pull_chef_image
        start_chef_container state

        # data
        make_data_image
        start_data_container state

        # work image
        build_work_image state

        # runner
        start_runner_container state

        # misc
        save_misc_state state
      end

      def destroy(_state)
        delete_data
        delete_runner
        delete_work_image
      end

      private

      def connection
        @connection ||= begin
                          opts = Docker.options
                          opts[:read_timeout] = 3600
                          opts[:write_timeout] = 3600
                          Docker::Connection.new(Docker.url, opts)
                        end
      end

      def delete_work_image
        return unless Docker::Image.exist?(work_image, connection)
        i = Docker::Image.get(work_image, connection)
        i.remove(force: true)
      end

      def build_work_image(state)
        return if Docker::Image.exist?(work_image, connection)

        FileUtils.mkdir_p context_root
        File.write("#{context_root}/Dockerfile", work_image_dockerfile)

        i = Docker::Image.build_from_dir(context_root, { 'nocache' => true, 'rm' => true }, connection)
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

      def delete_data
        debug "driver - deleting container #{data_container_name}"
        delete_container data_container_name
      end

      def start_runner_container(state)
        debug "driver - starting #{runner_container_name}"
        runner_container = run_container(
          'name' => runner_container_name,
          'Cmd' => Shellwords.shellwords(config[:pid_one_command]),
          'Image' => "#{repo(work_image)}:#{tag(work_image)}",
          'HostConfig' => {
            'Privileged' => config[:privileged],
            'VolumesFrom' => [chef_container_name, data_container_name]
          }
        )
        state[:runner_container] = runner_container.json
      end

      def start_data_container(state)
        debug "driver - creating #{data_container_name}"
        data_container = run_container(
          'name' => data_container_name,
          'Image' => "#{repo(data_image)}:#{tag(data_image)}",
          'PortBindings' => {
            '22/tcp' => [
              { 'HostPort' => '' }
            ]
          },
          'PublishAllPorts' => true
        )
        state[:data_container] = data_container.json
      end

      def make_data_image
        # debug "driver - pulling #{data_image}"
        # pull_if_missing data_image
        # -- or --
        debug 'driver - calling create_data_image'
        create_data_image
      end

      def start_chef_container(state)
        c = Docker::Container.get(chef_container_name)
      rescue Docker::Error::NotFoundError
        begin
          debug "driver - creating volume container #{chef_container_name} from #{chef_image}"
          chef_container = create_container(
            'name' => chef_container_name,
            'Cmd' => 'true',
            'Image' => "#{repo(chef_image)}:#{tag(chef_image)}"
          )
          state[:chef_container] = chef_container.json
        rescue
          debug "driver - #{chef_container_name} alreay exists"
        end
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
        i = Docker::Image.get(name, connection)
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
        c = Docker::Container.get(name, connection)
        puts "Destroying container #{name}."
        c.stop
        c.delete(force: true, v: true)
      rescue
        puts "Container #{name} not found. Nothing to delete."
      end

      def container_exist?(name)
        return true if Docker::Container.get(name)
      rescue
        false
      end

      def create_container(args)
        c = Docker::Container.create(args.clone, connection)
      rescue Docker::Error::ConflictError
        c = Docker::Container.get(args['name'])
      end

      def repo(image)
        image.split(':')[0]
      end

      def tag(image)
        image.split(':')[1] || 'latest'
      end

      def pull_image(image)
        retries ||= 3
        Docker::Image.create({ 'fromImage' => repo(image), 'tag' => tag(image) }, connection)
      rescue Docker::Error => e
        retry unless (tries -= 1).zero?
        raise e.message
      end

      def pull_if_missing(image)
        return if Docker::Image.exist?("#{repo(image)}:#{tag(image)}", connection)
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
        "chef-#{chef_version}"
      end

      def data_image
        'someara/kitchen-cache:latest'
      end

      def data_container_name
        # "#{instance.suite.name}-data"
        "#{instance.name}-data"
      end

      def runner_container_name
        "#{instance.name}"
      end
    end
  end
end
