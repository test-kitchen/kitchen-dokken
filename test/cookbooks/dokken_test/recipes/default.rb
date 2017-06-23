docker_service 'default' do
  host ['tcp://127.0.0.1']
  action [:create, :start]
end

user 'notroot' do
  home '/home/notroot'
  manage_home true
  action :create
end

package_list = %w(git ruby ruby-devel rubygem-io-console rubygem-bundler rubygem-rake gcc redhat-rpm-config libffi libffi-devel)

package package_list do
  action :install
end

git '/home/notroot/kitchen-dokken' do
  repository 'https://github.com/someara/kitchen-dokken'
  revision 'master'
  user 'notroot'
  action :sync
end

execute 'install gem bundle' do
  command '/usr/bin/bundle install'
  cwd '/home/notroot/kitchen-dokken'
  user 'notroot'
  live_stream false
  creates '/home/notroot/kitchen-dokken/Gemfile.lock'
  environment 'HOME' => '/home/notroot'
  action :run
end

execute 'converge hello with -c' do
  command '/usr/bin/bundle exec kitchen verify hello -c'
  cwd '/home/notroot/kitchen-dokken'
  user 'notroot'
  live_stream true
  environment 'PATH' => '/usr/bin:/usr/local/bin:/home/notroot/bin',
              'HOME' => '/home/notroot',
              'DOCKER_HOST' => 'tcp://127.0.0.1:2375'
  action :run
end

execute 'destroy hello again suite' do
  command '/usr/bin/bundle exec kitchen destroy helloagain'
  cwd '/home/notroot/kitchen-dokken'
  user 'notroot'
  live_stream true
  environment 'PATH' => '/usr/bin:/usr/local/bin:/home/notroot/bin',
              'HOME' => '/home/notroot',
              'DOCKER_HOST' => 'tcp://127.0.0.1:2375'
  action :run
end
