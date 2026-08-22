# Shared behaviour for the kitchen-dokken driver, provisioner and transport.
#
# Each of those three plugins mixes this in (at the top level, so the methods
# also land on Object) and supplies the small contract the helpers depend on:
# `config`, `instance`, `self[]`, `info` and `debug`.
module Dokken
  # @see Kitchen::Driver::Dokken
  # @see Kitchen::Provisioner::Dokken
  # @see Kitchen::Transport::Dokken
  module Helpers
    require "digest" unless defined?(Digest)
    require "fileutils" unless defined?(FileUtils)
    # https://stackoverflow.com/questions/517219/ruby-see-if-a-port-is-open
    require "socket" unless defined?(Socket)
    require "timeout" unless defined?(Timeout)
    require "tmpdir" unless defined?(Dir.mktmpdir)
    require "resolv" unless defined?(Resolv)

    # How long to wait for a TCP connect before calling a port closed.
    PORT_PROBE_TIMEOUT = 1

    # Check whether something is accepting TCP connections at `ip:port`.
    #
    # Used by the transport to pick a reachable address for the data
    # container's sshd. Every failure mode -- refused, unroutable,
    # unresolvable, timed out -- is a "no" rather than an exception, because
    # the caller's job is to try the next candidate address, not to abort.
    #
    # @param ip [String] an address or hostname to probe
    # @param port [String, Integer] the TCP port to probe
    # @return [Boolean] true when the connection was accepted
    def port_open?(ip, port)
      Timeout.timeout(PORT_PROBE_TIMEOUT) do
        TCPSocket.new(ip, port).close
        true
      rescue SystemCallError, SocketError, IOError
        false
      end
    rescue Timeout::Error
      false
    end

    # The public half of the throwaway keypair baked into the data image.
    #
    # It is deliberately published: the data container is only reachable on
    # the local docker network for the life of one kitchen run, and shipping
    # a fixed key avoids generating one per instance.
    #
    # @return [String] an OpenSSH `authorized_keys` line
    def insecure_ssh_public_key
      <<~EOF
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCoJwyW7qNhw+NTuOjC4+RVpESl+JBXebXzB7JqxRgKAbymq6B39azEAiNx5NzHkWcQmOyQNhFpKFSAufegcXRS4ctS1LcElEoXe9brDAqKEBSkmnXYfZXMNIG0Enw4+5W/rZxHFCAlsUSAHYtYZEs+3CgbIWuHhZ95C8UC6nGLWHNZOjcbsYZFrnFfO0qg0ene2w8LKhxqj5X0MRSdCIn1IwyxIbl5NND5Yk1Hx8JKsJtTiNTdxssiMgmM5bvTbYQUSf8pbGrRI30VQKBgQ8/UkidZbaTfvzWXYpwcDUERSbzEYCvkUytTemZIv6uhpPxqkfjl6KEOOml/iGqquPEr test-kitchen-rsa
      EOF
    end

    # The private half of the throwaway keypair.
    #
    # Written to disk 0600 by the transport just before it shells out to
    # rsync or scp. See {#insecure_ssh_public_key} for why a fixed key is
    # acceptable here.
    #
    # @return [String] a PEM-encoded RSA private key
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

    # The Dockerfile used to build the data image.
    #
    # The data image exists to hold the kitchen and verifier sandboxes and
    # serve them over ssh, for the cases where the daemon cannot see the
    # local filesystem: a remote docker host, or kitchen itself running in a
    # container.
    #
    # @param registry [String, nil] a registry to pull the base image from
    # @return [String] the Dockerfile contents
    def data_dockerfile(registry)
      from = "almalinux:9"
      if registry
        from = "#{registry}/#{from}"
      end
      <<~EOF
        FROM #{from}
        MAINTAINER Sean OMeara "sean@sean.io"
        ENV LANG en_US.UTF-8

        RUN dnf -y install tar rsync openssh-server passwd git
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
        CMD [ "/usr/sbin/sshd", "-D", "-p", "22", "-o", "UseDNS=no", "-o", "MaxAuthTries=60", "-o", "UsePAM=no" ]

        VOLUME #{resolved_root_path}
        VOLUME /opt/verifier
      EOF
    end

    # Build and tag the data image, unless it is already present.
    #
    # @param registry [String, nil] a registry to pull the base image from
    # @return [void]
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

    # Work out which docker daemon to talk to when the user has not said.
    #
    # @return [String] a docker host URL
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

    # Fetch and cache the daemon's `/info` payload.
    #
    # The cache is keyed by host because the driver, provisioner and
    # transport each resolve their own `:docker_info` default, and a
    # kitchen.yml may point them at different daemons.
    #
    # @param docker_host [String] the docker host URL to query
    # @return [Hash] the daemon's info payload
    def docker_info(docker_host)
      ::Docker.url = docker_host

      # Keyed by host: the driver, provisioner and transport each resolve
      # their own :docker_info default and a kitchen.yml may point them at
      # different daemons. A single memo would hand the second caller the
      # first daemon's payload, which is what remote_docker_host? keys its
      # whole local-vs-remote decision off.
      @docker_info ||= {}
      @docker_info[docker_host] ||= ::Docker.info
    rescue Excon::Error::Socket
      puts "kitchen-dokken could not connect to the docker host at #{docker_host}. Is docker running?"
      exit!
    end

    # Create the kitchen and verifier sandbox directories on the host.
    #
    # @return [void]
    def dokken_create_sandbox
      info("Creating kitchen sandbox at #{dokken_kitchen_sandbox}")
      FileUtils.mkdir_p(dokken_kitchen_sandbox, mode: 0o755)

      info("Creating verifier sandbox at #{dokken_verifier_sandbox}")
      FileUtils.mkdir_p(dokken_verifier_sandbox, mode: 0o755)
    end

    # Remove the kitchen and verifier sandbox directories from the host.
    #
    # @return [void]
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

    # The home directory, in a form docker will accept in a bind mount spec.
    #
    # @return [String] an absolute path
    def home_dir
      # while dokken_binds avoid invalid bind mount spec "C:/Users/..." error by
      # remote docker host virtual box shared folder on boot2docker created by docker-machine in Windows
      # refs:
      # https://github.com/docker/machine/issues/1814
      # https://github.com/docker/toolbox/issues/607
      return Dir.home.sub "C:/Users", "/c/Users" if Dir.home =~ /^C:/ && remote_docker_host?

      Dir.home
    end

    # Where the provisioner stages files for this instance.
    #
    # @return [String] an absolute path on the host
    def dokken_kitchen_sandbox
      "#{home_dir}/.dokken/kitchen_sandbox/#{instance_name}"
    end

    # Where the verifier stages files for this instance.
    #
    # @return [String] an absolute path on the host
    def dokken_verifier_sandbox
      "#{home_dir}/.dokken/verifier_sandbox/#{instance_name}"
    end

    # A container-safe, collision-free name for this kitchen instance.
    #
    # The working directory is hashed into the prefix so that the same suite
    # in two checkouts does not fight over one set of containers.
    #
    # @return [String] the instance name
    def instance_name
      prefix = (Digest::SHA2.hexdigest FileUtils.pwd)[0, 10]
      "#{prefix}-#{instance.name}".downcase
    end

    # The `ExposedPorts` value for the runner container.
    #
    # @return [Hash, nil] a Docker API ExposedPorts hash
    def exposed_ports
      coerce_exposed_ports(config[:ports])
    end

    # Network creation options for the dokken network.
    #
    # @return [Hash] options for `POST /networks/create`
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

    # The `PortBindings` value for the runner container.
    #
    # @return [Hash, nil] a Docker API PortBindings hash
    def port_bindings
      coerce_port_bindings(config[:ports])
    end

    # Normalise a `ports:` setting into a Docker API ExposedPorts hash.
    #
    # @param v [Hash, Array<String>, String, nil] the configured ports
    # @return [Hash, nil] an ExposedPorts hash, or nil to omit the key
    def coerce_exposed_ports(v)
      case v
      when Hash, nil
        v
      else
        x = Array(v).map { |a| parse_port(a) }
        x.flatten!
        x.to_h { |y| [y["container_port"], {}] }
      end
    end

    # Normalise a `ports:` setting into a Docker API PortBindings hash.
    #
    # @param v [Hash, Array<String>, String, nil] the configured ports
    # @return [Hash, nil] a PortBindings hash, or nil to omit the key
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

    # Parse one docker-style port spec into its component bindings.
    #
    # Accepts `container`, `host:container` and `host_ip:host:container`,
    # each optionally suffixed with `/protocol` and each allowing an
    # inclusive `low-high` container port range.
    #
    # @param v [String] a port specification
    # @return [Array<Hash>] one entry per container port
    # @raise [Kitchen::UserError] if a port range is inverted
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
        low, high = port_range.split("-").map(&:to_i)
        raise Kitchen::UserError, "Invalid port range #{port_range.inspect} in port spec #{v.inspect}: the low port must not be greater than the high port" if low > high

        port_range = (low..high).to_a
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

    # Whether the daemon is somewhere that cannot see the local filesystem.
    #
    # Docker Desktop and Boot2Docker are reached over tcp but share the
    # host's files, so they count as local no matter what the URL says.
    #
    # @return [Boolean] true when the sandbox must be shipped over ssh
    def remote_docker_host?
      # Podman and some rootless daemons omit OperatingSystem entirely, so
      # coerce before matching rather than calling #include? on nil.
      operating_system = config[:docker_info].to_h["OperatingSystem"].to_s
      return false if operating_system.include?("Docker Desktop")
      return false if operating_system.include?("Boot2Docker")
      return true if /^tcp:/.match?(config[:docker_host_url])

      false
    end

    # Whether kitchen itself is running inside a container.
    #
    # @return [Boolean] true when running in Docker
    def running_inside_docker?
      File.file?("/.dockerenv")
    end

    # Whether kitchen is running inside Docker Desktop specifically.
    #
    # @return [Boolean] true when `host.docker.internal` resolves
    def running_inside_docker_desktop?
      Resolv.getaddress "host.docker.internal."
      true
    rescue
      false
    end

    # Where the verifier stages files for this instance.
    #
    # @return [String] an absolute path on the host
    def sandbox_path
      "#{Dir.home}/.dokken/verifier_sandbox/#{instance_name}"
    end

    # The entries staged in the verifier sandbox, for upload.
    #
    # @return [Array<String>] absolute paths
    def sandbox_dirs
      Dir.glob(File.join(sandbox_path, "*"))
    end

    # Create the verifier sandbox directory if it is missing.
    #
    # @return [void]
    def create_sandbox
      info("Creating kitchen sandbox in #{sandbox_path}")
      unless ::Dir.exist?(sandbox_path)
        FileUtils.mkdir_p(sandbox_path, mode: 0o755)
      end
    end

    # The path the kitchen sandbox is mounted at inside the container.
    #
    # @return [String] an absolute path inside the container
    def resolved_root_path
      instance.provisioner[:root_path] || "/opt/kitchen"
    end
  end
end

# Redirect the stock Test Kitchen sandboxes into ~/.dokken.
#
# Every dokken container bind-mounts (or rsyncs) these directories, so they
# have to live at a stable, per-instance path that the docker daemon can see
# -- not in the random tmpdir the base classes would otherwise use.
module Kitchen
  module Provisioner
    # @see Dokken::Helpers
    class Base
      # Create the kitchen sandbox under ~/.dokken.
      #
      # @return [void]
      def create_sandbox
        info("Creating kitchen sandbox in #{sandbox_path}")
        FileUtils.mkdir_p(sandbox_path, mode: 0o755)
      end

      # Where the provisioner stages files for this instance.
      #
      # this MUST be named 'sandbox_path' because ruby.
      #
      # @return [String] an absolute path on the host
      def sandbox_path
        "#{Dir.home}/.dokken/kitchen_sandbox/#{instance_name}"
      end

      # A container-safe, collision-free name for this kitchen instance.
      #
      # @return [String] the instance name
      # @see Dokken::Helpers#instance_name
      def instance_name
        prefix = (Digest::SHA2.hexdigest FileUtils.pwd)[0, 10]
        "#{prefix}-#{instance.name}".downcase
      end
    end
  end
end

# Redirect the stock verifier sandbox into ~/.dokken, and teach the verifier
# to upload it when the daemon cannot read the host filesystem.
module Kitchen
  # @see Kitchen::Verifier::Base
  module Verifier
    # @see Dokken::Helpers
    class Base
      # Create the verifier sandbox under ~/.dokken.
      #
      # @return [void]
      def create_sandbox
        info("Creating kitchen sandbox in #{sandbox_path}")
        unless ::Dir.exist?(sandbox_path)
          FileUtils.mkdir_p(sandbox_path, mode: 0o755)
        end
      end

      # Where the verifier stages files for this instance.
      #
      # @return [String] an absolute path on the host
      def sandbox_path
        "#{Dir.home}/.dokken/verifier_sandbox/#{instance_name}"
      end

      # A container-safe, collision-free name for this kitchen instance.
      #
      # @return [String] the instance name
      # @see Dokken::Helpers#instance_name
      def instance_name
        prefix = (Digest::SHA2.hexdigest FileUtils.pwd)[0, 10]
        "#{prefix}-#{instance.name}".downcase
      end

      # Run the verifier against the instance.
      #
      # Files are only uploaded when the driver built a data container, which
      # it does exactly when the daemon cannot read the host filesystem.
      #
      # @param state [Hash] mutable instance state
      # @return [void]
      # @raise [Kitchen::ActionFailed] if the transport fails
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
