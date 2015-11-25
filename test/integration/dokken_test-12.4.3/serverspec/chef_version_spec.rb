describe command('/opt/chef/embedded/bin/chef-client --version') do
  its(:stdout) { should match(/12.4.3/) }
end
