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
        # options = config.to_hash.merge(state)
        options = state
        @connection = Kitchen::Transport::Dokken::Connection.new(options, &block)
      end

      class Connection < Kitchen::Transport::Base::Connection
        def close
        end

        def execute(command)
          # egregious hack time!
          sha = Digest::SHA1.hexdigest command if command

          # hash of the chef-zero run_command String.
          start_runner if sha == 'c113f510caaf4534d9eca9bb5472a1fada770523'

          # hash of the busser run_command
          # require 'pry'; binding.pry
          busser_plugin_install if sha == '9834f8f4c0135397118b15508b31714edff7317e'
          busser_suite_cleanup if sha == '868ddb2ab6876396938eaecaad16b4f2099efaae'
          busser_test if sha == '5bacd56b57e0e9341e4dbdcda6c119d6b8bccc0f'
        end

        def login_command
          # puts "command"
          LoginCommand.new('ls', '-la')
          instance_name = options[:instance_name]
          instance_platform_name = options[:instance_platform_name]

          begin
            Docker::Image.get("someara/#{instance_name}")
            work_image = "someara/#{instance_name}"
          rescue
            work_image = instance_platform_name
          end

          LoginCommand.new("docker run -it #{work_image} /bin/bash", nil)
        end

        def upload(locals, remote)
          ip = ENV['DOCKER_HOST'].split('tcp://')[1].split(':')[0]
          port = options[:kitchen_container][:NetworkSettings][:Ports][:"22/tcp"][0][:HostPort]

          rsync_cmd = '/usr/bin/rsync -az '
          rsync_cmd << "-e \"ssh -o StrictHostKeyChecking=no -p #{port}\""
          rsync_cmd << " #{locals.join(' ')} root@#{ip}:#{remote}"

          system(rsync_cmd)
        end

        def wait_until_ready
        end

        private

        def start_runner
          instance_name = options[:instance_name]
          instance_platform_name = options[:instance_platform_name]

          begin
            Docker::Image.get("someara/#{instance_name}")
            work_image = "someara/#{instance_name}"
          rescue
            work_image = instance_platform_name
          end

          chef_run = Docker::Container.create(
            'name' => "chef_runner-#{instance_name}",
            'Cmd' => [
              '/opt/chef/embedded/bin/chef-client', '-z',
              '-c', '/tmp/kitchen/client.rb',
              '-j', '/tmp/kitchen/dna.json',
              '-F', 'doc'
            ],
            'Image' => work_image,
            'Tag' => 'latest',
            'VolumesFrom' => ["chef-#{instance_name}", "kitchen_cache-#{instance_name}"],
            # 'Tty' => true
            )

          # FIXME: chef - printf yields "normal" fucked up output
          # formatting. puts is readable, but has extra blank lines.
          # Clues for how to fix the Chef formatter once and for all
          # lie in here.
          # chef_run.tap(&:start).attach { |stream, chunk| printf "#{chunk}" }
          chef_run.tap(&:start).attach { |_stream, chunk| puts "#{chunk}" }

          new_image = chef_run.commit
          new_image.tag('repo' => "someara/#{instance_name}", 'tag' => 'latest', 'force' => 'true')

          chef_run.delete
        end

        def busser_plugin_install
          instance_name = options[:instance_name]
          instance_platform_name = options[:instance_platform_name]

          begin
            Docker::Image.get("someara/#{instance_name}")
            work_image = "someara/#{instance_name}"
          rescue
            work_image = instance_platform_name
          end

          busser_plugin_install = Docker::Container.create(
            'name' => "busser_plugin_install-#{instance_name}",
            'Cmd' => [
              '/bin/bash', '-c', "#{busser_install_script}"
            ],
            'Image' => work_image,
            'Tag' => 'latest',
            'VolumesFrom' => ["chef-#{instance_name}", "kitchen_cache-#{instance_name}"]
            )

          busser_plugin_install.tap(&:start).attach { |_stream, chunk| puts "#{chunk}" }
          busser_plugin_install.delete
        end

        def busser_suite_cleanup
          instance_name = options[:instance_name]
          instance_platform_name = options[:instance_platform_name]

          begin
            Docker::Image.get("someara/#{instance_name}")
            work_image = "someara/#{instance_name}"
          rescue
            work_image = instance_platform_name
          end

          busser_suite_cleanup = Docker::Container.create(
            'name' => "busser_suite_cleanup-#{instance_name}",
            'Cmd' => [
              '/bin/bash', '-c', "#{busser_suite_cleanup_script}"
            ],
            'Image' => work_image,
            'Tag' => 'latest',
            'VolumesFrom' => ["chef-#{instance_name}", "kitchen_cache-#{instance_name}"]
            )

          busser_suite_cleanup.tap(&:start).attach { |_stream, chunk| puts "#{chunk}" }
          busser_suite_cleanup.delete
        end

        def busser_test
          instance_name = options[:instance_name]
          instance_platform_name = options[:instance_platform_name]

          begin
            Docker::Image.get("someara/#{instance_name}")
            work_image = "someara/#{instance_name}"
          rescue
            work_image = instance_platform_name
          end

          busser_test = Docker::Container.create(
            'name' => "busser_test-#{instance_name}",
            'Cmd' => [
              '/bin/bash', '-c', "#{busser_test_script}"
            ],
            'Image' => work_image,
            'Tag' => 'latest',
            'VolumesFrom' => ["chef-#{instance_name}", "kitchen_cache-#{instance_name}"]
            )

          busser_test.tap(&:start).attach { |_stream, chunk| puts "#{chunk}" }
          busser_test.delete
        end

        def busser_install_script
          <<-EOS
          BUSSER_ROOT="/tmp/verifier"; export BUSSER_ROOT
          GEM_HOME="/tmp/verifier/gems"; export GEM_HOME
          GEM_PATH="/tmp/verifier/gems"; export GEM_PATH
          GEM_CACHE="/tmp/verifier/gems/cache"; export GEM_CACHE
          ruby="/opt/chef/embedded/bin/ruby"
          gem="/opt/chef/embedded/bin/gem"
          version="busser"
          gem_install_args="busser --no-rdoc --no-ri"
          busser="/tmp/verifier/bin/busser"
          plugins="busser-serverspec"

          $gem list busser -i 2>&1 >/dev/null
          if test $? -ne 0; then
            echo "-----> Installing Busser ($version)"
            $gem install $gem_install_args
          else
            echo "-----> Busser installation detected ($version)"
          fi

          if test ! -f "$BUSSER_ROOT/bin/busser"; then
            gem_bindir=`$ruby -rrubygems -e "puts Gem.bindir"`
            $gem_bindir/busser setup
          fi

          echo " Installing Busser plugins: $plugins"
          $busser plugin install $plugins
          EOS
        end

        def busser_suite_cleanup_script
          <<-EOS
          BUSSER_ROOT="/tmp/verifier"; export BUSSER_ROOT
          GEM_HOME="/tmp/verifier/gems"; export GEM_HOME
          GEM_PATH="/tmp/verifier/gems"; export GEM_PATH
          GEM_CACHE="/tmp/verifier/gems/cache"; export GEM_CACHE

          /tmp/verifier/bin/busser suite cleanup
          EOS
        end

        def busser_test_script
          <<-EOS
          BUSSER_ROOT="/tmp/verifier"; export BUSSER_ROOT
          GEM_HOME="/tmp/verifier/gems"; export GEM_HOME
          GEM_PATH="/tmp/verifier/gems"; export GEM_PATH
          GEM_CACHE="/tmp/verifier/gems/cache"; export GEM_CACHE

          /tmp/verifier/bin/busser test
          EOS
        end
      end
    end
  end
end
