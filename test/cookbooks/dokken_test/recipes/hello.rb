file '/hello' do
  action :create
end

package 'nmap-ncat' do
  action :install
end

execute 'hello' do
  command "nohup echo 'hello' | nc -l 1234 &"
  not_if "ps -ef | grep -v grep | grep 'nc -l 1234'"
  action :run
end
