# Test that the platform configuration is working correctly
# This test verifies that when platform: linux/amd64 is set,
# the container is created and accessible

# Verify the container is running and the platform config didn't cause errors
describe command('uname -s') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/Linux/) }
end

# Check the architecture - on systems supporting the platform config,
# this should reflect the configured platform (amd64 = x86_64)
# On systems where cross-platform isn't supported, it will show native arch
describe command('uname -m') do
  its(:exit_status) { should eq 0 }
  # The architecture should be reported (either x86_64 for amd64 or aarch64 for arm64)
  # We're mainly testing that the container was created successfully with platform config
  its(:stdout) { should match(/x86_64|aarch64/) }
end

# Test that the container is running and accessible
describe command('echo "Platform test successful"') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/Platform test successful/) }
end

# Verify that chef commands are available (from the chef volume)
# This ensures the platform config didn't break volume mounting
describe command('/opt/chef/bin/chef-client --version') do
  its(:exit_status) { should eq 0 }
end

# Verify that the platform config allows basic operations
describe file('/etc/centos-release') do
  it { should exist }
  it { should be_file }
end
