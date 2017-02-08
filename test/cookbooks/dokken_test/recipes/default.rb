docker_service 'default' do
  host ['tcp://127.0.0.1']
  action [:create, :start]
end

user 'notroot' do
  home '/home/notroot'
  manage_home true
  action :create
end

package 'git' do
  action :install
end

git '/home/notroot/kitchen-dokken' do
  repository 'https://github.com/someara/kitchen-dokken'
  revision 'master'
  user 'notroot'
  action :sync
end

package 'ruby23' do
  action :install
end

package 'ruby23-devel' do
  action :install
end

gem_package 'io-console' do
  action :install
end

gem_package 'bundler' do
  action :install
end

gem_package 'rake' do
  action :install
end

package 'gcc' do
  action :install
end

execute 'install gem bundle' do
  command 'bundle install'
  cwd '/home/notroot/kitchen-dokken'
  user 'notroot'
  live_stream false
  creates '/home/notroot/kitchen-dokken/Gemfile.lock'
  environment 'HOME' => '/home/notroot'
  action :run
end

execute 'converge hello with -c' do
  command 'bundle exec kitchen converge hello -c'
  cwd '/home/notroot/kitchen-dokken'
  user 'notroot'
  live_stream true
  environment 'PATH' =>'/usr/bin:/usr/local/bin:/home/notroot/bin',
              'HOME' => '/home/notroot',
              'DOCKER_HOST' => 'tcp://127.0.0.1:2375'
  action :run
end

execute 'destroy hello again suite' do
  command 'bundle exec kitchen destroy helloagain'
  cwd '/home/notroot/kitchen-dokken'
  user 'notroot'
  live_stream true
  environment 'PATH' =>'/usr/bin:/usr/local/bin:/home/notroot/bin',
              'HOME' => '/home/notroot',
              'DOCKER_HOST' => 'tcp://127.0.0.1:2375'
  action :run
end
