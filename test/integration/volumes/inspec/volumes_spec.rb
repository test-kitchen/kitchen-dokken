# driver: volumes (anonymous) and binds (host path, read-only)

describe directory("/var/log/dokken-volume") do
  it { should exist }
end

describe mount("/var/log/dokken-volume") do
  it { should be_mounted }
end

# The repository's own LICENSE, bind-mounted read-only from the host.
describe file("/mnt/license") do
  it { should exist }
  its("content") { should match(/Apache License/) }
end

describe mount("/mnt/license") do
  its("options") { should include "ro" }
end
