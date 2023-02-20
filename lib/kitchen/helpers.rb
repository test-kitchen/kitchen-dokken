module Dokken
  module Helpers
    # https://stackoverflow.com/questions/517219/ruby-see-if-a-port-is-open
    require "socket" unless defined?(Socket)
    require "timeout" unless defined?(Timeout)

    def port_open?(ip, port)
      begin
        Timeout.timeout(1) do
          s = TCPSocket.new(ip, port)
          s.close
          return true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, Errno::ENETDOWN
          return false
        end
      rescue Timeout::Error
      end
      false
    end

    def insecure_ssh_public_key
      <<~EOF
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCoJwyW7qNhw+NTuOjC4+RVpESl+JBXebXzB7JqxRgKAbymq6B39azEAiNx5NzHkWcQmOyQNhFpKFSAufegcXRS4ctS1LcElEoXe9brDAqKEBSkmnXYfZXMNIG0Enw4+5W/rZxHFCAlsUSAHYtYZEs+3CgbIWuHhZ95C8UC6nGLWHNZOjcbsYZFrnFfO0qg0ene2w8LKhxqj5X0MRSdCIn1IwyxIbl5NND5Yk1Hx8JKsJtTiNTdxssiMgmM5bvTbYQUSf8pbGrRI30VQKBgQ8/UkidZbaTfvzWXYpwcDUERSbzEYCvkUytTemZIv6uhpPxqkfjl6KEOOml/iGqquPEr test-kitchen-rsa
      EOF
    end

    def insecure_ssh_private_key
      <<~EOF
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

    def data_dockerfile(registry)
      from = "centos:7"
      if registry
        from = "#{registry}/#{from}"
      end
      <<~EOF
        FROM #{from}
        MAINTAINER Sean OMeara "sean@sean.io"
        ENV LANG en_US.UTF-8

        RUN yum -y install tar rsync openssh-server passwd git
        RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''

        # uncomment to debug cert issues
        # RUN echo 'root:dokkendokkendokken' | chpasswd
        # RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
        # RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

        RUN mkdir -p /root/.ssh/
        COPY authorized_keys /root/.ssh/authorized_keys
        RUN chmod 700 /root/.ssh/
        RUN chmod 600  /root/.ssh/authorized_keys

        EXPOSE 22
        CMD [ "/usr/sbin/sshd", "-D", "-p", "22", "-o", "UseDNS=no", "-o", "UsePrivilegeSeparation=no", "-o", "MaxAuthTries=60" ]

        VOLUME /opt/kitchen
        VOLUME /opt/verifier
      EOF
    end

    def create_data_image(registry)
      return if ::Docker::Image.exist?(data_image)

      tmpdir = Dir.tmpdir
      FileUtils.mkdir_p "#{tmpdir}/dokken"
      File.write("#{tmpdir}/dokken/Dockerfile", data_dockerfile(registry))
      File.write("#{tmpdir}/dokken/authorized_keys", insecure_ssh_public_key)

      i = ::Docker::Image.build_from_dir(
        "#{tmpdir}/dokken",
        "nocache" => true,
        "rm" => true
      )
      i.tag("repo" => repo(data_image), "tag" => tag(data_image), "force" => true)
    end

    def default_docker_host
      if ENV["DOCKER_HOST"]
        ENV["DOCKER_HOST"]
      elsif File.exist?("/var/run/docker.sock")
        "unix:///var/run/docker.sock"
      # TODO: Docker for Windows also operates over a named pipe at
      # //./pipe/docker_engine that can be used if named pipe support is
      # added to the docker-api gem.
      else
        "tcp://127.0.0.1:2375"
      end
    end

    def docker_info
      ::Docker.url = default_docker_host

      @docker_info ||= ::Docker.info
    rescue Excon::Error::Socket
      puts "kitchen-dokken could not connect to the docker host at #{default_docker_host}. Is docker running?"
      exit!
    end

    def dokken_create_sandbox
      info("Creating kitchen sandbox at #{dokken_kitchen_sandbox}")
      FileUtils.mkdir_p(dokken_kitchen_sandbox, mode: 0o755)

      info("Creating verifier sandbox at #{dokken_verifier_sandbox}")
      FileUtils.mkdir_p(dokken_verifier_sandbox, mode: 0o755)
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

    def home_dir
      # while dokken_binds avoid invalid bind mount spec "C:/Users/..." error by
      # remote docker host virtual box shared folder on boot2docker created by docker-machine in Windows
      # refs:
      # https://github.com/docker/machine/issues/1814
      # https://github.com/docker/toolbox/issues/607
      return Dir.home.sub "C:/Users", "/c/Users" if Dir.home =~ /^C:/ && remote_docker_host?

      Dir.home
    end

    def dokken_kitchen_sandbox
      "#{home_dir}/.dokken/kitchen_sandbox/#{instance_name}"
    end

    def dokken_verifier_sandbox
      "#{home_dir}/.dokken/verifier_sandbox/#{instance_name}"
    end

    def instance_name
      prefix = (Digest::SHA2.hexdigest FileUtils.pwd)[0, 10]
      "#{prefix}-#{instance.name}"
    end

    def exposed_ports
      coerce_exposed_ports(config[:ports])
    end

    def network_settings
      if self[:ipv6]
        {
          "EnableIPv6" => true,
          "IPAM" => {
            "Config" => [{
              "Subnet" => self[:ipv6_subnet],
            }],
          },
        }
      else
        {}
      end
    end

    def port_bindings
      coerce_port_bindings(config[:ports])
    end

    def coerce_exposed_ports(v)
      case v
      when Hash, nil
        v
      else
        x = Array(v).map { |a| parse_port(a) }
        x.flatten!
        x.each_with_object({}) do |y, h|
          h[y["container_port"]] = {}
        end
      end
    end

    def coerce_port_bindings(v)
      case v
      when Hash, nil
        v
      else
        x = Array(v).map { |a| parse_port(a) }
        x.flatten!
        x.each_with_object({}) do |y, h|
          h[y["container_port"]] = [] unless h[y["container_port"]]
          h[y["container_port"]] << {
            "HostIp" => y["host_ip"],
            "HostPort" => y["host_port"],
          }
        end
      end
    end

    def parse_port(v)
      parts = v.split(":")
      case parts.length
      when 3
        host_ip = parts[0]
        host_port = parts[1]
        container_port = parts[2]
      when 2
        host_ip = "0.0.0.0"
        host_port = parts[0]
        container_port = parts[1]
      when 1
        host_ip = ""
        host_port = ""
        container_port = parts[0]
      end
      port_range, protocol = container_port.split("/")
      if port_range.include?("-")
        port_range = container_port.split("-")
        port_range.map!(&:to_i)
        Chef::Log.fatal("FATAL: Invalid port range! #{container_port}") if port_range[0] > port_range[1]
        port_range = (port_range[0]..port_range[1]).to_a
      end
      # qualify the port-binding protocol even when it is implicitly tcp #427.
      protocol = "tcp" if protocol.nil?
      Array(port_range).map do |port|
        {
          "host_ip" => host_ip,
          "host_port" => host_port,
          "container_port" => "#{port}/#{protocol}",
        }
      end
    end

    def remote_docker_host?
      return false if config[:docker_info]["OperatingSystem"].include?("Docker Desktop")
      return false if config[:docker_info]["OperatingSystem"].include?("Boot2Docker")
      return true if /^tcp:/.match?(config[:docker_host_url])

      false
    end

    def sandbox_path
      "#{Dir.home}/.dokken/verifier_sandbox/#{instance_name}"
    end

    def sandbox_dirs
      Dir.glob(File.join(sandbox_path, "*"))
    end

    def create_sandbox
      info("Creating kitchen sandbox in #{sandbox_path}")
      unless ::Dir.exist?(sandbox_path)
        FileUtils.mkdir_p(sandbox_path, mode: 0o755)
      end
    end
  end
end

module Kitchen
  module Provisioner
    class Base
      def create_sandbox
        info("Creating kitchen sandbox in #{sandbox_path}")
        FileUtils.mkdir_p(sandbox_path, mode: 0o755)
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
        unless ::Dir.exist?(sandbox_path)
          FileUtils.mkdir_p(sandbox_path, mode: 0o755)
        end
      end

      def sandbox_path
        "#{Dir.home}/.dokken/verifier_sandbox/#{instance_name}"
      end

      def instance_name
        prefix = (Digest::SHA2.hexdigest FileUtils.pwd)[0, 10]
        "#{prefix}-#{instance.name}"
      end

      def call(state)
        create_sandbox
        instance.transport.connection(state) do |conn|
          conn.execute(install_command)

          unless state[:data_container].nil?
            conn.execute(init_command)
            info("Transferring files to #{instance.to_str}")
            conn.upload(sandbox_dirs, config[:root_path])
            debug("Transfer complete")
          end

          conn.execute(prepare_command)
          conn.execute(run_command)
        end
      rescue Kitchen::Transport::TransportFailed => ex
        raise ActionFailed, ex.message
      end
    end
  end
end
