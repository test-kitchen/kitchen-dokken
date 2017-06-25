user 'notroot' do
  home '/home/notroot'
  manage_home true
  action :create
end

package_list = %w(
  gcc
  git
  iputils
  libffi
  libffi-devel
  net-tools
  nmap
  procps-ng
  redhat-rpm-config
  ruby
  ruby-devel
  rubygem-bundler
  rubygem-io-console
  rubygem-rake
  telnet
  which
)

package package_list

docker_service 'default' do
  host ['tcp://127.0.0.1']
  action [:create, :start]
end

git '/home/notroot/kitchen-dokken' do
  repository '/opt/kitchen-dokken/.git'
  revision node['dokken_test']['revision']
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

execute 'Test Kitchen verify hello' do
  command <<-EOH.gsub(/^\s{4}/, '').chomp
    /usr/bin/bundle exec kitchen create hello -l debug
    /usr/bin/bundle exec kitchen converge hello -l debug
    /usr/bin/bundle exec kitchen verify hello -l debug
  EOH
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
