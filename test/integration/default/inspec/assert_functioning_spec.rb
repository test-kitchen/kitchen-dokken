# The baseline every suite reuses: the converge really happened, the container
# really is init-managed, and the driver's own fingerprints are on it.

control "converge" do
  impact 1.0
  title "the run_list applied inside the container"

  describe file("/opt/dokken-test/converged") do
    it { should exist }
    its("content") { should eq "ok\n" }
    its("mode") { should cmp "0644" }
  end

  describe user("dokken") do
    it { should exist }
  end
end

control "chef-client" do
  impact 0.7
  title "the client is mounted from the volume container rather than installed"

  # /opt/cinc comes from the cinc volume container via VolumesFrom. If the
  # mount were missing the converge could not have run at all, but assert it
  # explicitly so a broken mount is reported as such.
  describe file("/opt/cinc/bin/cinc-client") do
    it { should exist }
    it { should be_executable }
  end
end

control "pid-one" do
  impact 0.7
  title "pid_one_command booted a real init"

  # This is what makes the `service` resource usable in a dokken container,
  # and it is the single most common thing users get wrong.
  describe file("/proc/1/comm") do
    its("content") { should match(/systemd/) }
  end
end

control "driver-env" do
  impact 0.5
  title "the driver stamps every container it creates"

  describe os_env("TEST_KITCHEN") do
    its("content") { should eq "1" }
  end
end
