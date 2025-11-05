describe file("/etc/resolv.conf") do
  it { should exist }
  its("content") { should match(/nameserver 8\.8\.8\.8/) }
  its("content") { should match(/nameserver 8\.8\.4\.4/) }
  its("content") { should match(/search example\.com/) }
end
