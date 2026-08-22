# driver: memory_limit
#
# 512MiB. The cgroup path differs between v1 and v2 hosts, so accept either.

describe.one do
  describe file("/sys/fs/cgroup/memory.max") do
    its("content") { should match(/^536870912$/) }
  end

  describe file("/sys/fs/cgroup/memory/memory.limit_in_bytes") do
    its("content") { should match(/^536870912$/) }
  end
end
