# Runs in the `helloagain` container while `hello` is up alongside it. Between
# them these assertions cover the driver's networking responsibilities: naming
# the container, registering aliases on the dokken network, and passing the
# environment through.

control "hostname" do
  impact 0.7
  title "the driver sets the container hostname from kitchen.yml"

  describe sys_info do
    its("hostname") { should eq "helloagain.computers.biz" }
  end
end

control "network-aliases" do
  impact 1.0
  title "peers on the dokken network resolve each other by hostname"

  # This is the driver's actual job: creating the dokken network and
  # registering each container's hostname and hostname_aliases as endpoint
  # aliases on it. Resolution is the assertion -- carrying a listener around
  # just to open a socket would test busybox, not kitchen-dokken.
  describe command("getent hosts hello.computers.biz") do
    its("exit_status") { should eq 0 }
  end

  describe command("getent hosts helloagain") do
    its("exit_status") { should eq 0 }
  end
end

control "environment" do
  impact 0.7
  title "env from kitchen.yml reaches the container"

  describe os_env("FOO") do
    its("content") { should eq "BAR" }
  end
end
