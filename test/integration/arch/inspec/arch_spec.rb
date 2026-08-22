# driver: platform
#
# The runner and the cinc volume container are both pinned to linux/arm64, so
# the container the tests run in must actually be aarch64 rather than the
# runner's native x86_64.

describe command("uname -m") do
  its("exit_status") { should eq 0 }
  its("stdout") { should match(/aarch64|arm64/) }
end
