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
require 'digest/sha1'

module Kitchen
  module Transport
    # Wrapped exception for any internally raised errors.
    #
    # @author Sean OMeara <sean@chef.io>
    class DokkenFailed < TransportFailed; end

    class Dokken < Kitchen::Transport::Base
      kitchen_transport_api_version 1

      plugin_version Kitchen::VERSION

      def connection(state, &block)
        options = config.to_hash.merge(state)
        Kitchen::Transport::Dokken::Connection.new(options, &block)
      end

      class Connection < Kitchen::Transport::Dokken::Connection
        def close
          puts "transport - doing some closing"
        end

        def execute(command)
          puts "transport - docker exec busser command"
        end

        def upload(locals, remote)
          puts "transport - doing some uploading"
        end

        def wait_until_ready
          puts "transport - waiting until ready"
        end
      end
    end
  end
end
