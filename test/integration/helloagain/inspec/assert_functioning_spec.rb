control "Verify Hostname" do
  impact 0.7
  title "Hostname should be set"
  desc "Test to see if the hostname is set correctly via kitchen.yml"

  describe sys_info do
    its("hostname") { should eq "helloagain.computers.biz" }
  end
end

control "Container group" do
  impact 0.7
  title "HelloAgain should be able to access the hello container"

  describe host("hello.computers.biz:1234", port: 1234, protocol: "tcp") do
    it { should be_reachable }
  end
end

control "Environment Variables" do
  impact 0.7
  title "Environment variables should be able to be passed through"

  describe os_env("FOO") do
    its("content") { should eq "BAR" }
  end
end
