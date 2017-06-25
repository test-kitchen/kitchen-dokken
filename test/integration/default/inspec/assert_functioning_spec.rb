
describe command('docker --host 127.0.0.1 ps') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/hello-hello$/) }
end

describe command('docker --host 127.0.0.1 ps') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/hello-hello-data$/) }
end

describe command('docker --host 127.0.0.1 ps') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should_not match(/helloagain-hello$/) }
end
