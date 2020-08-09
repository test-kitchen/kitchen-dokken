user 'notroot' do
  home '/home/notroot'
  manage_home true
  action :create
end

yum_repository 'chef-stable' do
  description 'chef-stable'
  baseurl 'https://packages.chef.io/repos/yum/stable/el/7/$basearch'
  gpgkey 'https://packages.chef.io/chef.asc'
end

package %w(
  gcc-c++
  gcc
  git
  iputils
  libffi
  libffi-devel
  make
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
  chef-workstation
)

docker_service 'default' do
  action [:create, :start]
end

# ruby_block 'docker info' do
#   block do
#     Chef::Log.warn(`docker -H 127.0.0.1 info`)
#   end
# end

# return # we know this is broken...

git '/home/notroot/kitchen-dokken' do
  repository '/opt/kitchen-dokken/.git'
  revision node['dokken_test']['revision']
  user 'notroot'
  action :sync
end


execute 'Test Kitchen verify hello' do
  command <<-EOH.gsub(/^\s{4}/, '').chomp
    /usr/bin/kitchen create hello -l debug
    /usr/bin/kitchen converge hello -l debug
    /usr/bin/kitchen verify hello -l debug
  EOH
  cwd '/home/notroot/kitchen-dokken'
  user 'notroot'
  live_stream true
  environment 'PATH' => '/usr/bin:/usr/local/bin:/home/notroot/bin',
              'HOME' => '/home/notroot',
              'CHEF_LICENSE' => 'accept-no-persist'
  action :run
end

execute 'destroy hello again suite' do
  command '/usr/bin/kitchen destroy helloagain'
  cwd '/home/notroot/kitchen-dokken'
  user 'notroot'
  live_stream true
  environment 'PATH' => '/usr/bin:/usr/local/bin:/home/notroot/bin',
              'HOME' => '/home/notroot'
  action :run
end

docker_tag 'local-example' do
  target_repo 'fedora'
  target_tag 'latest'
  to_repo 'local-example'
  to_tag 'latest'
end

execute 'Test Kitchen verify without image pull' do
  command '/usr/bin/kitchen test local_image -l debug'
  cwd '/home/notroot/kitchen-dokken'
  user 'notroot'
  live_stream true
  environment 'PATH' => '/usr/bin:/usr/local/bin:/home/notroot/bin',
              'HOME' => '/home/notroot',
              'CHEF_LICENSE' => 'accept-no-persist'
  action :run
end
