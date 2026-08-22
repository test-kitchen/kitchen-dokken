# driver: tmpfs

describe mount("/mnt/dokken-tmpfs") do
  it { should be_mounted }
  its("type") { should eq "tmpfs" }
  its("options") { should include "noexec" }
  its("options") { should include "nosuid" }
end
