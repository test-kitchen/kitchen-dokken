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

execute 'bundle install' do
  cwd '/home/notroot/kitchen-dokken'
  environment 'HOME' => '/home/notroot'
  user 'notroot'
  creates '/home/notroot/kitchen-dokken/Gemfile.lock'
  action :run
end
