require_relative "../spec_helper"

require "kitchen/helpers"

describe Dokken::Helpers do
  Host = Kitchen::Dokken::Spec::HelperHost
  FakeInstance = Kitchen::Dokken::Spec::FakeInstance

  let(:instance) { FakeInstance.new(provisioner: { root_path: "/opt/kitchen" }) }
  let(:config)   { {} }
  let(:host)     { Host.new(config: config, instance: instance) }

  describe "#port_open?" do
    it "is true for a port that is accepting connections" do
      server = TCPServer.new("127.0.0.1", 0)
      begin
        _(host.port_open?("127.0.0.1", server.addr[1])).must_equal true
      ensure
        server.close
      end
    end

    it "is false for a port nothing is listening on" do
      server = TCPServer.new("127.0.0.1", 0)
      port = server.addr[1]
      server.close

      _(host.port_open?("127.0.0.1", port)).must_equal false
    end

    it "is false when the connection times out" do
      TCPSocket.stubs(:new).raises(Timeout::Error)

      _(host.port_open?("10.255.255.1", 22)).must_equal false
    end

    # Reachability probing must never be the thing that aborts a converge.
    # An unresolvable hostname is a "no", not an exception to propagate into
    # Transport#upload's ip-selection ladder.
    it "is false when the host cannot be resolved" do
      TCPSocket.stubs(:new).raises(SocketError, "getaddrinfo: nodename nor servname provided")

      _(host.port_open?("no-such-host.invalid", 22)).must_equal false
    end

    it "is false when the route to the host is unavailable" do
      TCPSocket.stubs(:new).raises(Errno::EHOSTUNREACH)

      _(host.port_open?("192.0.2.1", 22)).must_equal false
    end

    it "is false when the connection times out at the socket layer" do
      TCPSocket.stubs(:new).raises(Errno::ETIMEDOUT)

      _(host.port_open?("192.0.2.1", 22)).must_equal false
    end
  end

  describe "the built-in insecure keypair" do
    it "offers an ssh-rsa public key" do
      _(host.insecure_ssh_public_key).must_match(/\Assh-rsa AAAA/)
    end

    it "offers the matching PEM private key" do
      _(host.insecure_ssh_private_key).must_match(/\A-----BEGIN RSA PRIVATE KEY-----\n/)
      _(host.insecure_ssh_private_key).must_match(/-----END RSA PRIVATE KEY-----\n\z/)
    end

    it "produces a private key OpenSSL can actually load" do
      require "openssl"
      key = OpenSSL::PKey::RSA.new(host.insecure_ssh_private_key)
      _(key.private?).must_equal true
    end

    # The data container authorises the public key and the transport signs
    # with the private one, so a mismatched pair would break every upload.
    it "produces a public key that matches the private key" do
      require "openssl"
      require "base64"

      private_key = OpenSSL::PKey::RSA.new(host.insecure_ssh_private_key)
      wire = Base64.decode64(host.insecure_ssh_public_key.split[1])

      # OpenSSH wire format: a sequence of length-prefixed fields, here
      # "ssh-rsa", then the public exponent, then the modulus.
      fields = []
      offset = 0
      while offset < wire.bytesize
        length = wire.byteslice(offset, 4).unpack1("N")
        offset += 4
        fields << wire.byteslice(offset, length)
        offset += length
      end

      _(fields[0]).must_equal "ssh-rsa"
      _(OpenSSL::BN.new(fields[1], 2)).must_equal private_key.e
      _(OpenSSL::BN.new(fields[2], 2)).must_equal private_key.n
    end
  end

  describe "#data_dockerfile" do
    it "builds from the bare almalinux image when no registry is configured" do
      _(host.data_dockerfile(nil)).must_match(/^FROM almalinux:9$/)
    end

    it "prefixes the base image with a configured registry" do
      _(host.data_dockerfile("registry.example.com")).must_match(%r{^FROM registry\.example\.com/almalinux:9$})
    end

    it "exposes ssh and declares the sandbox volumes" do
      dockerfile = host.data_dockerfile(nil)

      _(dockerfile).must_match(/^EXPOSE 22$/)
      _(dockerfile).must_match(%r{^VOLUME /opt/kitchen$})
      _(dockerfile).must_match(%r{^VOLUME /opt/verifier$})
    end

    it "declares the volume at the provisioner's configured root_path" do
      instance.provisioner[:root_path] = "/somewhere/else"

      _(host.data_dockerfile(nil)).must_match(%r{^VOLUME /somewhere/else$})
    end

    it "installs the packages the transport's rsync and scp paths need" do
      _(host.data_dockerfile(nil)).must_match(/dnf -y install .*\brsync\b/)
      _(host.data_dockerfile(nil)).must_match(/dnf -y install .*\bopenssh-server\b/)
    end
  end

  describe "#default_docker_host" do
    it "prefers DOCKER_HOST when it is set" do
      ENV.stubs(:[]).with("DOCKER_HOST").returns("tcp://10.0.0.1:2376")

      _(host.default_docker_host).must_equal "tcp://10.0.0.1:2376"
    end

    it "falls back to the local socket when it exists" do
      ENV.stubs(:[]).with("DOCKER_HOST").returns(nil)
      File.stubs(:exist?).with("/var/run/docker.sock").returns(true)

      _(host.default_docker_host).must_equal "unix:///var/run/docker.sock"
    end

    it "falls back to the default tcp endpoint when there is no socket" do
      ENV.stubs(:[]).with("DOCKER_HOST").returns(nil)
      File.stubs(:exist?).with("/var/run/docker.sock").returns(false)

      _(host.default_docker_host).must_equal "tcp://127.0.0.1:2375"
    end
  end

  describe "#docker_info" do
    before do
      @original_url = ::Docker.url
    end

    after do
      ::Docker.url = @original_url
    end

    it "points the docker client at the requested host" do
      ::Docker.stubs(:info).returns("OperatingSystem" => "Ubuntu")
      host.docker_info("tcp://10.0.0.1:2376")

      _(::Docker.url).must_equal "tcp://10.0.0.1:2376"
    end

    it "returns the daemon's info payload" do
      ::Docker.stubs(:info).returns("OperatingSystem" => "Ubuntu")

      _(host.docker_info("unix:///var/run/docker.sock")).must_equal("OperatingSystem" => "Ubuntu")
    end

    it "asks the daemon only once for a repeated host" do
      ::Docker.expects(:info).once.returns("OperatingSystem" => "Ubuntu")

      host.docker_info("unix:///var/run/docker.sock")
      host.docker_info("unix:///var/run/docker.sock")
    end

    # The driver, provisioner and transport each resolve their own
    # :docker_info default, and a kitchen.yml may point them at different
    # daemons. Caching one payload for every host hands the second caller the
    # first daemon's OperatingSystem, which is what remote_docker_host? keys
    # its whole unix-vs-tcp decision off.
    it "asks again when a different host is requested" do
      ::Docker.stubs(:info)
        .returns({ "OperatingSystem" => "Docker Desktop" })
        .then.returns({ "OperatingSystem" => "Ubuntu 24.04" })

      _(host.docker_info("unix:///var/run/docker.sock")["OperatingSystem"]).must_equal "Docker Desktop"
      _(host.docker_info("tcp://10.0.0.1:2376")["OperatingSystem"]).must_equal "Ubuntu 24.04"
    end

    # An unreachable daemon used to `puts` and then `exit!`, which takes the
    # whole kitchen process down from inside a default_config block: no
    # kitchen error banner, no `.kitchen/logs`, every other instance in the
    # run abandoned, and nothing a spec could assert on. A UserError is what
    # Test Kitchen already knows how to report.
    it "raises a Kitchen error when the daemon refuses the connection" do
      ::Docker.stubs(:info).raises(Excon::Error::Socket)

      err = _ { host.docker_info("tcp://10.0.0.1:2376") }.must_raise Kitchen::UserError

      _(err.message).must_include "tcp://10.0.0.1:2376"
    end

    it "says how to fix an unreachable daemon rather than just that it failed" do
      ::Docker.stubs(:info).raises(Excon::Error::Socket)

      err = _ { host.docker_info("unix:///var/run/docker.sock") }.must_raise Kitchen::UserError

      _(err.message.downcase).must_include "is docker running"
    end

    # The memo must not cache the failure. A daemon that was down when the
    # driver resolved its default and is up by the time the transport resolves
    # its own should work.
    it "does not cache a failed lookup" do
      ::Docker.stubs(:info)
        .raises(Excon::Error::Socket)
        .then.returns({ "OperatingSystem" => "Ubuntu 24.04" })

      _ { host.docker_info("unix:///var/run/docker.sock") }.must_raise Kitchen::UserError

      _(host.docker_info("unix:///var/run/docker.sock")["OperatingSystem"]).must_equal "Ubuntu 24.04"
    end
  end

  describe "the kitchen and verifier sandboxes" do
    before do
      stub_home!
      FileUtils.stubs(:pwd).returns("/some/project")
    end

    it "namespaces the sandbox by a hash of the working directory" do
      digest = Digest::SHA2.hexdigest("/some/project")[0, 10]

      _(host.instance_name).must_equal "#{digest}-default-almalinux-9"
    end

    it "downcases the instance name so it is a legal container name" do
      host.instance.stubs(:name).returns("Default-AlmaLinux-9")

      _(host.instance_name).must_match(/\A[a-z0-9-]+\z/)
    end

    it "puts the kitchen sandbox under ~/.dokken" do
      _(host.dokken_kitchen_sandbox).must_equal "#{tmphome}/.dokken/kitchen_sandbox/#{host.instance_name}"
    end

    it "puts the verifier sandbox under ~/.dokken" do
      _(host.dokken_verifier_sandbox).must_equal "#{tmphome}/.dokken/verifier_sandbox/#{host.instance_name}"
    end

    it "creates both sandboxes" do
      host.dokken_create_sandbox

      _(File.directory?(host.dokken_kitchen_sandbox)).must_equal true
      _(File.directory?(host.dokken_verifier_sandbox)).must_equal true
    end

    it "creates the sandboxes world-readable so the container can read them" do
      host.dokken_create_sandbox

      _(File.stat(host.dokken_kitchen_sandbox).mode & 0o777).must_equal 0o755
    end

    it "deletes both sandboxes and everything in them" do
      host.dokken_create_sandbox
      File.write(File.join(host.dokken_kitchen_sandbox, "dna.json"), "{}")

      host.dokken_delete_sandbox

      _(File.exist?(host.dokken_kitchen_sandbox)).must_equal false
      _(File.exist?(host.dokken_verifier_sandbox)).must_equal false
    end

    # `kitchen destroy` runs on instances that never got as far as creating a
    # sandbox, and runs again on instances that are already destroyed. Neither
    # may raise. This is a property of FileUtils.rm_rf, which swallows a
    # missing path rather than raising Errno::ENOENT -- the reason the two
    # rescues that used to sit here could never fire.
    it "is a no-op to delete sandboxes that were never created" do
      host.dokken_delete_sandbox

      _(File.exist?(host.dokken_kitchen_sandbox)).must_equal false
    end

    it "is a no-op to delete the same sandboxes twice" do
      host.dokken_create_sandbox
      host.dokken_delete_sandbox

      host.dokken_delete_sandbox

      _(File.exist?(host.dokken_kitchen_sandbox)).must_equal false
    end
  end

  describe "#home_dir" do
    it "is the real home directory on a unix host" do
      Dir.stubs(:home).returns("/home/someone")

      _(host.home_dir).must_equal "/home/someone"
    end

    # boot2docker/docker-machine shares C:\Users as /c/Users, so a Windows
    # path has to be rewritten before it can be used as a bind mount spec.
    it "rewrites a Windows home directory for a remote docker host" do
      Dir.stubs(:home).returns("C:/Users/someone")
      host.stubs(:remote_docker_host?).returns(true)

      _(host.home_dir).must_equal "/c/Users/someone"
    end

    it "leaves a Windows home directory alone for a local docker host" do
      Dir.stubs(:home).returns("C:/Users/someone")
      host.stubs(:remote_docker_host?).returns(false)

      _(host.home_dir).must_equal "C:/Users/someone"
    end
  end

  describe "#parse_port" do
    it "treats a bare port as container-only with no host binding" do
      _(host.parse_port("80")).must_equal [
        { "host_ip" => "", "host_port" => "", "container_port" => "80/tcp" },
      ]
    end

    it "binds host:container on all interfaces" do
      _(host.parse_port("8080:80")).must_equal [
        { "host_ip" => "0.0.0.0", "host_port" => "8080", "container_port" => "80/tcp" },
      ]
    end

    it "honours an explicit host ip" do
      _(host.parse_port("127.0.0.1:8080:80")).must_equal [
        { "host_ip" => "127.0.0.1", "host_port" => "8080", "container_port" => "80/tcp" },
      ]
    end

    # Fixed in #427: an unqualified port must still land in the bindings hash
    # as "<port>/tcp", because that is the key the Docker API expects.
    it "qualifies an implicit protocol as tcp" do
      _(host.parse_port("53").first["container_port"]).must_equal "53/tcp"
    end

    it "keeps an explicit protocol" do
      _(host.parse_port("53/udp").first["container_port"]).must_equal "53/udp"
    end

    it "expands an inclusive container port range" do
      _(host.parse_port("8080-8082").map { |p| p["container_port"] }).must_equal %w{8080/tcp 8081/tcp 8082/tcp}
    end

    it "expands a port range while keeping the protocol" do
      _(host.parse_port("8080-8082/udp").map { |p| p["container_port"] }).must_equal %w{8080/udp 8081/udp 8082/udp}
    end

    it "expands a bound port range" do
      parsed = host.parse_port("0.0.0.0:9000:9000-9001")

      _(parsed.map { |p| p["container_port"] }).must_equal %w{9000/tcp 9001/tcp}
      _(parsed.map { |p| p["host_ip"] }.uniq).must_equal ["0.0.0.0"]
    end

    # An inverted range used to reach for Chef::Log, a constant kitchen-dokken
    # never requires, so the user got `uninitialized constant Chef` instead of
    # being told which port spec was wrong.
    it "raises a Kitchen error naming the bad range" do
      err = _ { host.parse_port("9001-9000") }.must_raise Kitchen::UserError

      _(err.message).must_include "9001-9000"
    end

    # A spec with more colons than the three documented forms used to fall off
    # the end of the case statement, leaving container_port nil and blowing up
    # with `undefined method 'split' for nil` several lines later. An IPv6 host
    # address is the way a user actually hits this: "[::1]:8500:8500" splits
    # into five parts, not three.
    it "raises a Kitchen error for a spec with too many parts" do
      err = _ { host.parse_port("[::1]:8500:8500") }.must_raise Kitchen::UserError

      _(err.message).must_include "[::1]:8500:8500"
    end

    it "raises a Kitchen error rather than failing on nil somewhere downstream" do
      err = _ { host.parse_port("1:2:3:4") }.must_raise Kitchen::UserError

      _(err.message).must_include "1:2:3:4"
    end

    it "raises a Kitchen error for an empty spec" do
      _ { host.parse_port("") }.must_raise Kitchen::UserError
    end

    # `"8080-".split("-")` is ["8080"], not ["8080", ""] -- Ruby drops
    # trailing empty fields -- so the high port was nil and the guard below
    # compared an Integer against it. The user saw "comparison of Integer
    # with nil failed" for what was simply a typo in kitchen.yml.
    it "names the range rather than comparing a port against nil" do
      err = _ { host.parse_port("8080-") }.must_raise Kitchen::UserError

      _(err.message).must_include "8080-"
    end

    it "rejects a range with no low port" do
      _ { host.parse_port("-8080") }.must_raise Kitchen::UserError
    end

    it "rejects a range whose ends are not numbers" do
      _ { host.parse_port("http-https") }.must_raise Kitchen::UserError
    end

    # `"/".split("/")` is [], so port_range was nil and `include?` blew up.
    it "rejects a spec that is nothing but a protocol separator" do
      _ { host.parse_port("/") }.must_raise Kitchen::UserError
    end

    it "rejects a protocol with no port in front of it" do
      err = _ { host.parse_port("/tcp") }.must_raise Kitchen::UserError

      _(err.message).must_include "no container port"
    end

    it "still accepts the boundary case of a single-port range" do
      _(host.parse_port("8080-8080").map { |p| p["container_port"] }).must_equal ["8080/tcp"]
    end
  end

  describe "#coerce_exposed_ports" do
    it "passes nil through so the Docker API omits the key" do
      _(host.coerce_exposed_ports(nil)).must_be_nil
    end

    it "passes an explicit hash through untouched" do
      explicit = { "80/tcp" => {} }

      _(host.coerce_exposed_ports(explicit)).must_equal explicit
    end

    it "turns a single port string into an ExposedPorts hash" do
      _(host.coerce_exposed_ports("80")).must_equal("80/tcp" => {})
    end

    it "turns a list of port strings into one ExposedPorts hash" do
      _(host.coerce_exposed_ports(["8080:80", "53/udp"])).must_equal("80/tcp" => {}, "53/udp" => {})
    end

    it "expands a range into one entry per port" do
      _(host.coerce_exposed_ports(["9000-9002"]).keys).must_equal %w{9000/tcp 9001/tcp 9002/tcp}
    end
  end

  describe "#coerce_port_bindings" do
    it "passes nil through so the Docker API omits the key" do
      _(host.coerce_port_bindings(nil)).must_be_nil
    end

    it "passes an explicit hash through untouched" do
      explicit = { "80/tcp" => [{ "HostIp" => "", "HostPort" => "8080" }] }

      _(host.coerce_port_bindings(explicit)).must_equal explicit
    end

    it "builds a PortBindings hash from a host:container spec" do
      _(host.coerce_port_bindings(["8080:80"])).must_equal(
        "80/tcp" => [{ "HostIp" => "0.0.0.0", "HostPort" => "8080" }]
      )
    end

    it "collects several host bindings for one container port" do
      _(host.coerce_port_bindings(["127.0.0.1:8080:80", "10.0.0.1:9090:80"])).must_equal(
        "80/tcp" => [
          { "HostIp" => "127.0.0.1", "HostPort" => "8080" },
          { "HostIp" => "10.0.0.1", "HostPort" => "9090" },
        ]
      )
    end

    it "expands a range into one binding per port" do
      _(host.coerce_port_bindings(["9000-9001"]).keys).must_equal %w{9000/tcp 9001/tcp}
    end
  end

  describe "#exposed_ports and #port_bindings" do
    it "read the :ports config key" do
      config[:ports] = ["8080:80"]

      _(host.exposed_ports).must_equal("80/tcp" => {})
      _(host.port_bindings).must_equal("80/tcp" => [{ "HostIp" => "0.0.0.0", "HostPort" => "8080" }])
    end
  end

  describe "#network_settings" do
    it "is empty when ipv6 is off" do
      config[:ipv6] = false

      _(host.network_settings).must_equal({})
    end

    it "enables ipv6 and pins the subnet when ipv6 is on" do
      config[:ipv6] = true
      config[:ipv6_subnet] = "2001:db8:1::/64"

      _(host.network_settings).must_equal(
        "EnableIPv6" => true,
        "IPAM" => { "Config" => [{ "Subnet" => "2001:db8:1::/64" }] }
      )
    end
  end

  describe "#remote_docker_host?" do
    it "is false for Docker Desktop even over tcp, since it shares the host filesystem" do
      config[:docker_info] = Kitchen::Dokken::Spec.docker_info(operating_system: "Docker Desktop")
      config[:docker_host_url] = "tcp://127.0.0.1:2375"

      _(host.remote_docker_host?).must_equal false
    end

    it "is false for Boot2Docker even over tcp" do
      config[:docker_info] = Kitchen::Dokken::Spec.docker_info(operating_system: "Boot2Docker 20.10")
      config[:docker_host_url] = "tcp://192.168.99.100:2376"

      _(host.remote_docker_host?).must_equal false
    end

    it "is true for a plain daemon reached over tcp" do
      config[:docker_info] = Kitchen::Dokken::Spec.docker_info(operating_system: "Ubuntu 24.04")
      config[:docker_host_url] = "tcp://10.0.0.1:2376"

      _(host.remote_docker_host?).must_equal true
    end

    it "is false for a daemon reached over a unix socket" do
      config[:docker_info] = Kitchen::Dokken::Spec.docker_info(operating_system: "Ubuntu 24.04")
      config[:docker_host_url] = "unix:///var/run/docker.sock"

      _(host.remote_docker_host?).must_equal false
    end

    # Podman and some rootless daemons omit OperatingSystem entirely; calling
    # .include? on the resulting nil aborted `kitchen create` before it got as
    # far as talking to the daemon.
    it "treats a daemon that reports no OperatingSystem as remote when reached over tcp" do
      config[:docker_info] = {}
      config[:docker_host_url] = "tcp://10.0.0.1:2376"

      _(host.remote_docker_host?).must_equal true
    end

    it "treats a daemon that reports no OperatingSystem as local when reached over a socket" do
      config[:docker_info] = {}
      config[:docker_host_url] = "unix:///var/run/docker.sock"

      _(host.remote_docker_host?).must_equal false
    end
  end

  describe "#running_inside_docker?" do
    it "is true when /.dockerenv exists" do
      File.stubs(:file?).with("/.dockerenv").returns(true)

      _(host.running_inside_docker?).must_equal true
    end

    it "is false when /.dockerenv is absent" do
      File.stubs(:file?).with("/.dockerenv").returns(false)

      _(host.running_inside_docker?).must_equal false
    end
  end

  describe "#running_inside_docker_desktop?" do
    it "is true when host.docker.internal resolves" do
      Resolv.stubs(:getaddress).with("host.docker.internal.").returns("192.168.65.2")

      _(host.running_inside_docker_desktop?).must_equal true
    end

    it "is false when host.docker.internal does not resolve" do
      Resolv.stubs(:getaddress).raises(Resolv::ResolvError)

      _(host.running_inside_docker_desktop?).must_equal false
    end
  end

  describe "the verifier sandbox" do
    before do
      stub_home!
      FileUtils.stubs(:pwd).returns("/some/project")
    end

    it "lists nothing before anything is staged" do
      host.create_sandbox

      _(host.sandbox_dirs).must_equal []
    end

    it "lists the staged entries once they exist" do
      host.create_sandbox
      FileUtils.mkdir_p(File.join(host.sandbox_path, "cookbooks"))
      File.write(File.join(host.sandbox_path, "dna.json"), "{}")

      _(host.sandbox_dirs.map { |d| File.basename(d) }.sort).must_equal %w{cookbooks dna.json}
    end

    it "is idempotent to create" do
      host.create_sandbox
      host.create_sandbox

      _(File.directory?(host.sandbox_path)).must_equal true
    end
  end

  describe "#resolved_root_path" do
    it "is the provisioner's root_path when one is set" do
      instance.provisioner[:root_path] = "/opt/somewhere"

      _(host.resolved_root_path).must_equal "/opt/somewhere"
    end

    it "falls back to /opt/kitchen" do
      instance.provisioner[:root_path] = nil

      _(host.resolved_root_path).must_equal "/opt/kitchen"
    end
  end
  # helpers.rb reopens the stock Test Kitchen base classes so that every plugin
  # -- including verifiers kitchen-dokken does not ship -- stages its files in
  # the per-instance ~/.dokken directories the containers mount.
  describe "the Test Kitchen base-class patches" do
    let(:logged_output) { StringIO.new }
    let(:kitchen_logger) { Logger.new(logged_output) }
    let(:kitchen_instance) do
      stub(name: "default-almalinux-9", logger: kitchen_logger, to_str: "default-almalinux-9")
    end

    before do
      stub_home!
      FileUtils.stubs(:pwd).returns("/some/project")
    end

    describe Kitchen::Provisioner::Base do
      let(:base) do
        Kitchen::Provisioner::Base.new(kitchen_root: "/rooty").finalize_config!(kitchen_instance)
      end

      it "stages under ~/.dokken/kitchen_sandbox rather than a tmpdir" do
        _(base.sandbox_path).must_equal "#{tmphome}/.dokken/kitchen_sandbox/#{base.instance_name}"
      end

      it "namespaces the sandbox by working directory and instance" do
        digest = Digest::SHA2.hexdigest("/some/project")[0, 10]

        _(base.instance_name).must_equal "#{digest}-default-almalinux-9"
      end

      it "creates the sandbox directory" do
        base.create_sandbox

        _(File.directory?(base.sandbox_path)).must_equal true
      end
    end

    describe Kitchen::Verifier::Base do
      let(:transport)  { stub("transport") }
      let(:connection) { mock("connection") }
      let(:verifier) do
        Kitchen::Verifier::Base.new(root_path: "/opt/verifier").finalize_config!(kitchen_instance)
      end

      before do
        kitchen_instance.stubs(:transport).returns(transport)
        transport.stubs(:connection).yields(connection).returns(nil)
        connection.stubs(:execute)
        connection.stubs(:upload)
      end

      it "stages under ~/.dokken/verifier_sandbox" do
        _(verifier.sandbox_path).must_equal "#{tmphome}/.dokken/verifier_sandbox/#{verifier.instance_name}"
      end

      it "creates the sandbox directory" do
        verifier.create_sandbox

        _(File.directory?(verifier.sandbox_path)).must_equal true
      end

      it "is idempotent to create" do
        verifier.create_sandbox
        verifier.create_sandbox

        _(File.directory?(verifier.sandbox_path)).must_equal true
      end

      # On a local daemon the driver never builds a data container, because the
      # sandbox is bind-mounted straight in -- so there is nothing to upload.
      it "does not upload anything when there is no data container" do
        connection.expects(:upload).never

        verifier.call({})
      end

      it "uploads the sandbox when a data container exists" do
        verifier.create_sandbox
        File.write(File.join(verifier.sandbox_path, "inspec.yml"), "---")
        connection.expects(:upload).with([File.join(verifier.sandbox_path, "inspec.yml")], "/opt/verifier")

        verifier.call(data_container: { "Name" => "/data" })
      end

      it "translates a transport failure into a kitchen action failure" do
        connection.stubs(:execute).raises(Kitchen::Transport::TransportFailed, "verify failed")

        err = _ { verifier.call({}) }.must_raise Kitchen::ActionFailed

        _(err.message).must_include "verify failed"
      end
    end
  end
end
