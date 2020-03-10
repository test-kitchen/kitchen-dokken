#
# Author:: Sean OMeara (<sean@sean.io>)
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
require_relative '../helpers'

include Dokken::Helpers

module Kitchen
  module Provisioner
    # @author Sean OMeara <sean@sean.io>
    class Dokken < Kitchen::Provisioner::ChefZero
      kitchen_provisioner_api_version 2

      plugin_version Kitchen::VERSION

      default_config :root_path, '/opt/kitchen'
      default_config :chef_binary, '/opt/chef/bin/chef-client'
      default_config :chef_options, ' -z'
      default_config :chef_log_level, 'warn'
      default_config :chef_output_format, 'doc'
      default_config :docker_info, docker_info
      default_config :docker_host_url, default_docker_host

      # Dokken is weird - the provisioner inherits from ChefZero but does not install
      # chef-client. The version of chef used is customized by users in the driver
      # section since it is just downloading a specific Docker image of Chef Client.
      # In order to get the license-acceptance code working though (which depends on
      # the product_version from the provisioner) we need to copy the value from the
      # driver and set it here. If we remove this, users will set their chef_version
      # to 14 in the driver and still get prompted for license acceptance because
      # the ChefZero provisioner defaults product_version to 'latest'.
      default_config :product_name, 'chef'
      default_config :product_version do |provisioner|
        driver = provisioner.instance.driver
        driver[:chef_version]
      end

      # (see Base#call)
      def call(state)
        create_sandbox
        instance.transport.connection(state) do |conn|
          if remote_docker_host?
            info("Transferring files to #{instance.to_str}")
            conn.upload(sandbox_dirs, config[:root_path])
          end

          conn.execute(prepare_command)
          conn.execute_with_retry(
            run_command,
            config[:retry_on_exit_code],
            config[:max_retries],
            config[:wait_for_retry]
          )
        end
      rescue Kitchen::Transport::TransportFailed => ex
        raise ActionFailed, ex.message
      ensure
        cleanup_dokken_sandbox
      end

      def validate_config
        # check if we have an space for the user provided options
        # or add it if not to avoid issues
        unless config[:chef_options].start_with? ' '
          config[:chef_options].prepend(' ')
        end

        # strip spaces from all other options
        config[:chef_binary] = config[:chef_binary].strip
        config[:chef_log_level] = config[:chef_log_level].strip
        config[:chef_output_format] = config[:chef_output_format].strip

        # if the user wants to be funny and pass empty strings
        # just use the defaults
        config[:chef_log_level] = 'warn' if config[:chef_log_level].empty?
        config[:chef_output_format] = 'doc' if config[:chef_output_format].empty?
      end

      private

      # patching Kitchen::Provisioner::ChefZero#run_command
      def run_command
        validate_config
        cmd = config[:chef_binary]
        cmd << config[:chef_options].to_s
        cmd << " -l #{config[:chef_log_level]}"
        cmd << " -F #{config[:chef_output_format]}"
        cmd << ' -c /opt/kitchen/client.rb'
        cmd << ' -j /opt/kitchen/dna.json'
      end

      def runner_container_name
        instance.name.to_s
      end

      def cleanup_dokken_sandbox
        return if sandbox_path.nil?

        debug("Cleaning up local sandbox in #{sandbox_path}")
        FileUtils.rmtree(Dir.glob("#{sandbox_path}/*"))
      end
    end
  end
end
