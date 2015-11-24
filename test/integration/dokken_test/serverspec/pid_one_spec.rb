require 'serverspec'

set :backend, :exec

puts "os: #{os}"

# based on the platform settings in .kitchen.yml

# centos
if os[:family] =~ /redhat/
  # no pid_one_command set
  if os[:release] =~ /6\./
    describe command('ps -ef') do
      its(:stdout) { should match(/sh -c trap exit 0 SIGTERM; while :; do sleep 1; done/) }
    end
  end

  # systemd platforms
  if os[:release] =~ /7\./
    describe command('ps -ef') do
      its(:stdout) { should match(%r{/usr/lib/systemd/systemd}) }
    end
  end
end

# fedora
if os[:family] =~ /fedora/
  describe command('ps -ef') do
    its(:stdout) { should match(%r{/usr/lib/systemd/systemd}) }
  end
end

# debian
if os[:family] =~ /debian/ && command("cat /etc/issue | grep 'Linux 7'").stdout =~ /7/
  describe command('cat /proc/1/cmdline') do
    its(:stdout) { should match(/trap exit 0 SIGTERM; while :; do sleep 1; done/) }
  end
end

if os[:family] =~ /debian/ && command("cat /etc/issue | grep 'Linux 8'").stdout =~ /8/
  describe command('cat /proc/1/cmdline') do
    its(:stdout) { should match(%r{/bin/systemd}) }
  end
end

# ubuntu
if os[:family] =~ /ubuntu/
  if os[:release] =~ /12.04/
    describe command('ps -ef') do
      its(:stdout) { should match(%r{/sbin/init}) }
    end
  end

  if os[:release] =~ /14.04/
    describe command('ps -ef') do
      its(:stdout) { should match(%r{/sbin/init}) }
    end
  end

  if os[:release] =~ /15.10/
    describe command('ps -ef') do
      its(:stdout) { should match(%r{/bin/systemd}) }
    end
  end
end
