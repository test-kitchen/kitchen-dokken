require 'serverspec'

set :backend, :exec

describe command('/opt/chef/embedded/bin/chef-client --version') do
  its(:stdout) { should match(/12.5.1/) }
end
