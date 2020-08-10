
describe command('docker ps') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/hello-hello$/) }
end

describe command('docker ps') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/hello-hello-data$/) }
end

describe command('docker ps') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should_not match(/helloagain-hello$/) }
end
