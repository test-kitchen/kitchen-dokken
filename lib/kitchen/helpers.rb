module Dokken
  module Helpers
    def insecure_ssh_public_key
      <<-EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCoJwyW7qNhw+NTuOjC4+RVpESl+JBXebXzB7JqxRgKAbymq6B39azEAiNx5NzHkWcQmOyQNhFpKFSAufegcXRS4ctS1LcElEoXe9brDAqKEBSkmnXYfZXMNIG0Enw4+5W/rZxHFCAlsUSAHYtYZEs+3CgbIWuHhZ95C8UC6nGLWHNZOjcbsYZFrnFfO0qg0ene2w8LKhxqj5X0MRSdCIn1IwyxIbl5NND5Yk1Hx8JKsJtTiNTdxssiMgmM5bvTbYQUSf8pbGrRI30VQKBgQ8/UkidZbaTfvzWXYpwcDUERSbzEYCvkUytTemZIv6uhpPxqkfjl6KEOOml/iGqquPEr test-kitchen-rsa
EOF
    end

    def insecure_ssh_private_key
      <<-EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAqCcMlu6jYcPjU7jowuPkVaREpfiQV3m18weyasUYCgG8pqug
d/WsxAIjceTcx5FnEJjskDYRaShUgLn3oHF0UuHLUtS3BJRKF3vW6wwKihAUpJp1
2H2VzDSBtBJ8OPuVv62cRxQgJbFEgB2LWGRLPtwoGyFrh4WfeQvFAupxi1hzWTo3
G7GGRa5xXztKoNHp3tsPCyocao+V9DEUnQiJ9SMMsSG5eTTQ+WJNR8fCSrCbU4jU
3cbLIjIJjOW7022EFEn/KWxq0SN9FUCgYEPP1JInWW2k3781l2KcHA1BEUm8xGAr
5FMrU3pmSL+roaT8apH45eihDjppf4hqqrjxKwIDAQABAoIBAEj7Cb/IOykHd/ay
XnOXrVZuQU03oI4WyR19zbYBbPmK33IHM1JdUmqP8wpPpnMHbJALj0DX9p6JXoOw
MwVzuGTwkuqUYAqgwbeHjDPfugNKD2uRjmwztXw3ncOl8jxZFRloJFfFKF6znWNt
bzkh7naN3upHiv/6wsgqj4tAbZ9oRC1crO6bsNr3P6YooiG5RRNpHepiyXphyhN6
We1p5ZOQ/pUSE0Ca4wTlUhJHTUPMz7VFs/8CH0loRIsGPBROarPkoLVF+/UNyX8e
+BGMhoUtQH2XvjEzWUl5jKJOnvKRIV+0j/upWXsPQKF5glVPmPrTVUAxThfu6rAa
4Z3JveECgYEA0Pz3Hl0SlPR79r2qofh1ZNa8zvQDL+iLopULwDiil5qlUxJ+DgOl
1kWXLhjdg/NfoTBHvBjdJu274YJgaGQOfCy5747YDVsakKOm4bI9+Jr2agshPyE6
f1RNmGL8K8fNtpGq4G14o+pSQOPNrEfcFKgm3sosZWJAWaA64hmtiXcCgYEAzfp6
FbodfUypAV5Zd6PCO2eJMjLdvGaNuH/Umo80WNV7XZ6iJ6MUeQe+YwxFJigjC3ii
ifLUj3kL7+wu7sEtkzS3zNd34KfhQ5fLADttfFgjjfm7IxlDD4ABaUgjwZM2gfXi
xCwRhwwNgilF6qABJ1CLt8JSqKubkqvO1P1gQu0CgYEA0GA6AcNpYK344Eey1/bF
DntyHKN+fglPGReldM7Dh4gBabgZid2nP+N5XtQaIpPKeQyLqgfckhEecTau68dA
Dh4Gcs6pq394GFmkbotrcPMJ2SgpySlXi1fCWrvvlbON8IiDqWxdiop74wmArFOm
I86ZmzBYXeo+IV869vAFcPcCgYBrvvyh5OuMIc++YYZXaRgvTueblLQc22CDBItI
FmUBmxqfTF3ycgJBlWVoFoENhq1eUMplctrx+hXeeSPLzM10VX1X79ZLdEYHv513
D58kDk7684mKwKotr34NfqkFl2ZJ8T+f8pVwmUNvtPtX0j8IO7/6bfIjPTFyNeFJ
1QjHuQKBgQC/LE05M4eeWXihZ7c7fyWHLyddcPdH48LRF9UH9yjKF84jXRT91uMv
XuIb2Qt4MLHABySsk653LDw/jTIGV26c068nZryq5OUPxk67Xgod54jKgOwjgjZS
X8N2N9ZNnORJqK374yGj1jWUU66mQhPvn49QpG8P2HEoh2RQjNvyHA==
-----END RSA PRIVATE KEY-----
EOF
    end

    def data_dockerfile
      <<-EOF
FROM centos:7
MAINTAINER Sean OMeara \"sean@sean.io\"

ENV LANG en_US.UTF-8

RUN yum -y install tar rsync openssh-server passwd git
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''

RUN mkdir -p /root/.ssh/
COPY authorized_keys /root/.ssh/authorized_keys

EXPOSE 22
CMD [ "/usr/sbin/sshd", "-D", "-p", "22", "-o", "UseDNS=no", "-o", "UsePrivilegeSeparation=no", "-o", "MaxAuthTries=60" ]

VOLUME /opt/kitchen
VOLUME /opt/verifier
EOF
    end

    def create_data_image
      return if ::Docker::Image.exist?(data_image)

      tmpdir = Dir.tmpdir
      FileUtils.mkdir_p "#{tmpdir}/dokken"
      File.write("#{tmpdir}/dokken/Dockerfile", data_dockerfile)
      File.write("#{tmpdir}/dokken/authorized_keys", insecure_ssh_public_key)

      i = ::Docker::Image.build_from_dir(
        "#{tmpdir}/dokken",
        'nocache' => true,
        'rm' => true
      )
      i.tag('repo' => repo(data_image), 'tag' => tag(data_image), 'force' => true)
    end

    def default_docker_host
      if ENV['DOCKER_HOST']
        ENV['DOCKER_HOST']
      elsif File.exist?('/var/run/docker.sock')
        'unix:///var/run/docker.sock'
      # TODO: Docker for Windows also operates over a named pipe at
      # //./pipe/docker_engine that can be used if named pipe support is
      # added to the docker-api gem.
      else
        'tcp://127.0.0.1:2375'
      end
    end

    def dokken_create_sandbox
      info("Creating kitchen sandbox at #{dokken_kitchen_sandbox}")
      FileUtils.mkdir_p(dokken_kitchen_sandbox)
      File.chmod(0755, dokken_kitchen_sandbox)

      info("Creating verifier sandbox at #{dokken_verifier_sandbox}")
      FileUtils.mkdir_p(dokken_verifier_sandbox)
      File.chmod(0755, dokken_verifier_sandbox)
    end

    def dokken_delete_sandbox
      info("Deleting kitchen sandbox at #{dokken_kitchen_sandbox}")
      begin
        FileUtils.rm_rf(dokken_kitchen_sandbox)
      rescue Errno::ENOENT
        debug("Cannot delete #{dokken_kitchen_sandbox}. Does not exist")
      end

      info("Deleting verifier sandbox at #{dokken_verifier_sandbox}")
      begin
        FileUtils.rm_rf(dokken_verifier_sandbox)
      rescue Errno::ENOENT
        debug("Cannot delete #{dokken_verifier_sandbox}. Does not exist")
      end
    end

    def dokken_kitchen_sandbox
      "#{Dir.home}/.dokken/kitchen_sandbox/#{instance_name}"
    end

    def dokken_verifier_sandbox
      "#{Dir.home}/.dokken/verifier_sandbox/#{instance_name}"
    end

    def instance_name
      prefix = (Digest::SHA2.hexdigest FileUtils.pwd)[0, 10]
      "#{prefix}-#{instance.name}"
    end

    def remote_docker_host?
      return true if config[:docker_host_url] =~ /^tcp:/
      false
    end
  end
end

module Kitchen
  module Provisioner
    class Base
      def create_sandbox
        info("Creating kitchen sandbox in #{sandbox_path}")
        FileUtils.mkdir_p(sandbox_path)
        File.chmod(0755, sandbox_path)
      end

      # this MUST be named 'sandbox_path' because ruby.
      def sandbox_path
        "#{Dir.home}/.dokken/kitchen_sandbox/#{instance_name}"
      end

      def instance_name
        prefix = (Digest::SHA2.hexdigest FileUtils.pwd)[0, 10]
        "#{prefix}-#{instance.name}"
      end
    end
  end
end

module Kitchen
  module Verifier
    class Base
      def create_sandbox
        info("Creating kitchen sandbox in #{sandbox_path}")
        FileUtils.mkdir_p(sandbox_path)
        File.chmod(0755, sandbox_path)
      end

      def sandbox_path
        "#{Dir.home}/.dokken/verifier_sandbox/#{instance_name}"
      end

      def instance_name
        prefix = (Digest::SHA2.hexdigest FileUtils.pwd)[0, 10]
        "#{prefix}-#{instance.name}"
      end

      def call(state)
        instance.transport.connection(state) do |conn|
          conn.execute(install_command)
          conn.execute(prepare_command)
          conn.execute(run_command)
        end
      rescue Kitchen::Transport::TransportFailed => ex
        raise ActionFailed, ex.message
      ensure
        cleanup_sandbox
      end
    end
  end
end
