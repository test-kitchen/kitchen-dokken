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

require "kitchen"
require "kitchen/provisioner/chef_infra"
require_relative "../helpers"

include Dokken::Helpers

module Kitchen
  module Provisioner
    # @author Sean OMeara <sean@sean.io>
    class Dokken < Kitchen::Provisioner::ChefInfra
      kitchen_provisioner_api_version 2

      plugin_version Kitchen::VERSION

      default_config :root_path, "/opt/kitchen"
      default_config :chef_binary, "/opt/chef/bin/chef-client"
      default_config :chef_options, " -z"
      default_config :chef_log_level, "warn"
      default_config :chef_output_format, "doc"
      default_config :profile_ruby, false
      default_config :docker_info do |provisioner|
        docker_info(provisioner[:docker_host_url])
      end
      default_config :docker_host_url, default_docker_host

      # Dokken is weird - the provisioner inherits from ChefInfra but does not install
      # chef-client. The version of chef used is customized by users in the driver
      # section since it is just downloading a specific Docker image of Chef Client.
      # In order to get the license-acceptance code working though (which depends on
      # the product_version from the provisioner) we need to copy the value from the
      # driver and set it here. If we remove this, users will set their chef_version
      # to 14 in the driver and still get prompted for license acceptance because
      # the ChefInfra provisioner defaults product_version to 'latest'.
      default_config :product_name, "chef"
      default_config :product_version do |provisioner|
        driver = provisioner.instance.driver
        driver[:chef_version]
      end
      default_config :clean_dokken_sandbox, true

      # (see Base#call)
      def call(state)
        create_sandbox
        write_run_command(run_command)
        instance.transport.connection(state) do |conn|
          if remote_docker_host? || running_inside_docker?
            info("Transferring files to #{instance.to_str}")
            conn.upload(sandbox_dirs, config[:root_path])
          end

          conn.execute(prepare_command)
          conn.execute_with_retry(
            "sh #{config[:root_path]}/run_command",
            config[:retry_on_exit_code],
            config[:max_retries],
            config[:wait_for_retry]
          )
        end
      rescue Kitchen::Transport::TransportFailed => ex
        raise ActionFailed, ex.message
      ensure
        cleanup_dokken_sandbox if config[:clean_dokken_sandbox] # rubocop: disable Lint/EnsureReturn
      end

      def validate_config
        # check if we have an space for the user provided options
        # or add it if not to avoid issues
        unless config[:chef_options].start_with? " "
          config[:chef_options].prepend(" ")
        end

        # strip spaces from all other options
        config[:chef_binary] = config[:chef_binary].strip
        config[:chef_log_level] = config[:chef_log_level].strip
        config[:chef_output_format] = config[:chef_output_format].strip

        # if the user wants to be funny and pass empty strings
        # just use the defaults
        config[:chef_log_level] = "warn" if config[:chef_log_level].empty?
        config[:chef_output_format] = "doc" if config[:chef_output_format].empty?
      end

      private

      # patching Kitchen::Provisioner::ChefInfra#run_command
      def run_command
        validate_config
        cmd = chef_executable
        cmd << config[:chef_options].to_s
        cmd << " -l #{config[:chef_log_level]}"
        cmd << " -F #{config[:chef_output_format]}"
        cmd << " -c /opt/kitchen/client.rb"
        cmd << " -j /opt/kitchen/dna.json"
        cmd << " --profile-ruby" if config[:profile_ruby]
        cmd << " --slow-report" if config[:slow_resource_report]
        cmd << " --chef-license-key=#{config[:chef_license_key]}" if instance.driver.installer == "habitat" && config[:chef_license_key]

        chef_cmd(cmd)
      end

      def write_run_command(command)
        File.write("#{dokken_kitchen_sandbox}/run_command", command, mode: "wb")
      end

      def runner_container_name
        instance.name.to_s
      end

      def cleanup_dokken_sandbox
        return if sandbox_path.nil?

        debug("Cleaning up local sandbox in #{sandbox_path}")
        FileUtils.rmtree(Dir.glob("#{sandbox_path}/*"))
      end

      def chef_executable
        return  "#{config[:chef_binary]}" if instance.driver.installer == "chef"

        hab_bin = "HAB_BIN=$(find /hab/pkgs/core/hab/ -type f -name hab | sort | tail -n1)"
        "#{hab_bin} && HAB_LICENSE='accept-no-persist'  \"$HAB_BIN\" pkg exec chef/chef-infra-client -- chef-client "
      end

      # Override bypass_chef_licensing? hook to provide dokken-specific licensing bypass logic
      # This method is called by ChefInfra's check_license method to determine if licensing should be bypassed
      def bypass_chef_licensing?
        if private_registry_detected?
          debug("Skipping Chef license check - private registry usage detected")
          debug("Private registry users either have existing licenses or custom-built images")
          return true
        end

        false
      end

      # Detects if Dokken is configured to use a private Docker registry
      # Returns true if any private registry configuration is detected
      #
      # Cases considered as private/internal registries:
      # 1. driver[:docker_registry] - Explicit private registry URL configuration
      # 2. driver[:creds_file] - Explicit credentials file for private registry authentication
      # 3. driver[:docker_config_creds] - Using ~/.docker/config.json for authentication
      # 4. chef_image with domain patterns:
      #    - Domain-based: "registry.company.com/chef", "harbor.internal/image"
      #    - IP-based: "192.168.1.100/chef", "10.0.0.50:5000/image"
      #    - Localhost: "localhost:5000/chef", "127.0.0.1/image"
      #    - Custom ports: "myregistry:8080/chef"
      def private_registry_detected?
        driver = instance.driver

        # Explicit private registry configurations
        return true if driver[:docker_registry].to_s.strip != ""  # Case 1: docker_registry set
        return true if driver[:creds_file].to_s.strip != ""       # Case 2: creds_file provided
        return true if driver[:docker_config_creds]               # Case 3: docker_config_creds enabled

        # Detect private registries from chef_image hostname patterns
        chef_image = driver[:chef_image].to_s.strip
        return false if chef_image.empty? || !chef_image.include?("/")

        registry_host = chef_image.split("/").first.downcase

        # Case 4: chef_image contains private registry patterns
        return true if registry_host.include?(".") ||      # Domain-based registries
          registry_host.include?(":") ||                   # Custom port registries
          registry_host.match?(/\A(localhost|\d{1,3}(\.\d{1,3}){3})\z/) # Localhost/IP registries

        # Default: assume public registry (like 'chef/chef-hab')
        false
      end

    end
  end
end
