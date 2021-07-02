describe interface("eth0") do
  its("ipv6_cidrs") { should include(%r{2001:db8:1::\d/64}) }
end
