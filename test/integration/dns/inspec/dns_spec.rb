# driver: dns and dns_search
#
# On a user-defined network -- which dokken's default `dokken` network is --
# Docker runs an embedded resolver. /etc/resolv.conf then points at
# 127.0.0.11 and the configured servers are recorded as upstream `ExtServers`
# rather than as literal `nameserver` lines. On the default bridge, or with
# older engines, they are written out directly. Either shape means the driver
# passed HostConfig.Dns through, which is the thing under test.

describe file("/etc/resolv.conf") do
  it { should exist }
end

# Search domains are written verbatim in both modes.
describe file("/etc/resolv.conf") do
  its("content") { should match(/search example\.com/) }
end

describe.one do
  describe file("/etc/resolv.conf") do
    its("content") { should match(/nameserver 8\.8\.8\.8/) }
    its("content") { should match(/nameserver 8\.8\.4\.4/) }
  end

  describe file("/etc/resolv.conf") do
    its("content") { should match(/ExtServers:.*8\.8\.8\.8.*8\.8\.4\.4/) }
  end
end
