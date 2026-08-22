# The Chef Infra counterpart of test/integration/default, which asserts the
# Cinc paths. Only the client location differs.

describe file("/opt/dokken-test/converged") do
  it { should exist }
  its("content") { should eq "ok\n" }
end

describe file("/opt/chef/bin/chef-client") do
  it { should exist }
  it { should be_executable }
end

describe file("/proc/1/comm") do
  its("content") { should match(/systemd/) }
end
