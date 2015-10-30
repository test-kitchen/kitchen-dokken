# -*- encoding: utf-8 -*-
#
# Author:: Fletcher Nichol (<fnichol@nichol.ca>)
#
# Copyright (C) 2013, Fletcher Nichol
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

module Kitchen

  module Provisioner

    # Dummy provisioner for Kitchen. This driver does nothing but report what
    # would happen if this provisioner did anything of consequence. As a result
    # it may be a useful provisioner to use when debugging or developing new
    # features or plugins.
    #
    # @author Fletcher Nichol <fnichol@nichol.ca>
    class Dokken < Kitchen::Provisioner::Base

      kitchen_provisioner_api_version 2

      plugin_version Kitchen::VERSION

      default_config :sleep, 0
      default_config :random_failure, false

      # (see Base#call)
      def call(state)
        info("[#{name}] Converge on instance=#{instance} with state=#{state}")
        
        puts "provisioner - create instance_name variable from options"
        puts "provisioner - create instance_platform_name variable from options"
        puts "provisioner - pull someara/instance_name ?"
        puts "provisioner - create work_image from someara/instance_name ?"
        puts "provisioner - work_image = instance_platform_name"
        puts "provisioner - chef_run = docker run --volumes-from chef-instance_name --volumes-from kitchen-cache-instance_name work_image:latest chef-client -z -c -j -F"
        puts "provisioner - new_image = chef_run.commit"
        puts "provisioner - new_image.tag someara/instance_name latest"
        puts "provisioner - chef_run.delete"

        debug("[#{name}] Converge completed (#{config[:sleep]}s).")
      end

    end
  end
end
