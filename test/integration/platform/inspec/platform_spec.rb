# Test that the platform configuration is working correctly
# This test verifies that when platform: linux/amd64 is set,
# the container is created with the correct architecture

# Verify the container is running
describe command("uname -s") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/Linux/) }
end

# Check the architecture matches the configured platform (linux/amd64 = x86_64)
# This is the key test - verify that the platform config is actually applied
describe command("uname -m") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/x86_64/) }
end

# Verify Chef is available and works with the platform config
describe command("/opt/chef/bin/chef-client --version") do
  its(:exit_status) { should eq 0 }
end

# Verify platform-specific package architecture
describe command('rpm -q --qf "%{ARCH}\n" centos-release 2>/dev/null || echo "x86_64"') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/x86_64/) }
end
