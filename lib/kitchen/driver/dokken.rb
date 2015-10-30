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
Excon.defaults[:ssl_verify_peer] = false

module Kitchen
  module Driver
    # Dokken driver for Kitchen.
    #
    # @author Sean OMeara <sean@chef.io>
    class Dokken < Kitchen::Driver::Base

      # (see Base#create)
      def create(state)
        # pull images
        puts "driver - pulling someara/chef:latest"
        puts "driver - pulling someara/kitchen-cache:latest"
        puts "driver - pulling instance.platform.name:latest"

        # chef container
        puts "driver - creating volume container chef-instnace.name from someara/chef:12.5.1"
        puts "driver - saving container json to state[:chef_container]"

        # kitchen cache
        puts "driver - creating kitchen_container for instance.name"
        puts "driver - saving kitchen_container json to state[:kitchen_container]"
        puts "driver - saving instance_name to state object"
        puts "driver - saving instance_platform_name to state object"
      end

      def destroy(_state)        
        puts "driver - delete_container chef_runner-#{instance.name}"
        puts "driver - delete_container kitchen_cache-#{instance.name}"
        puts "driver - delete_container chef-#{instance.name}"
      end

    end
  end
end
