require_relative "../../spec_helper"

require "kitchen/driver/dokken"

describe Kitchen::Driver::Dokken do
  FakeContainer = Kitchen::Dokken::Spec::FakeContainer
  FakeImage     = Kitchen::Dokken::Spec::FakeImage

  let(:logged_output)      { StringIO.new }
  let(:logger)             { Logger.new(logged_output) }
  let(:platform)           { stub(name: "almalinux-9", os_type: nil) }
  let(:suite)              { stub(name: "default") }
  let(:transport)          { stub }
  let(:provisioner_config) { {} }
  let(:provisioner)        { provisioner_config }

  let(:instance) do
    stub(
      name: "default-almalinux-9",
      logger: logger,
      suite: suite,
      platform: platform,
      transport: transport,
      provisioner: provisioner,
      to_str: "default-almalinux-9"
    )
  end

  let(:config) { { docker_info: Kitchen::Dokken::Spec.docker_info } }

  let(:driver) do
    Kitchen::Driver::Dokken.new(config).finalize_config!(instance)
  end

  let(:connection) { stub("docker connection") }

  # Most driver internals reach the daemon through #docker_connection; giving
  # it a double keeps every example hermetic without stubbing the gem globally.
  def offline!
    driver.stubs(:docker_connection).returns(connection)
    driver.stubs(:sleep)
  end

  describe "defaults" do
    it "retries api calls 20 times" do
      _(driver[:api_retries]).must_equal 20
    end

    it "creates containers on the dokken network" do
      _(driver[:network_mode]).must_equal "dokken"
    end

    it "names the container host dokken" do
      _(driver[:hostname]).must_equal "dokken"
    end

    it "keeps pid 1 alive with a shell that traps SIGTERM" do
      _(driver[:pid_one_command]).must_include "trap exit 0 SIGTERM"
    end

    it "pulls the chef and platform images by default so runs stay current" do
      _(driver[:pull_chef_image]).must_equal true
      _(driver[:pull_platform_image]).must_equal true
    end

    it "does not pin a platform, so the daemon picks the host architecture" do
      _(driver[:platform]).must_equal ""
    end

    it "leaves ipv6 off but documents a reserved subnet for when it is on" do
      _(driver[:ipv6]).must_equal false
      _(driver[:ipv6_subnet]).must_equal "2001:db8:1::/64"
    end

    it "uses the published kitchen-cache image for the data container" do
      _(driver[:data_image]).must_equal "dokken/kitchen-cache:latest"
    end

    it "declares no memory limit" do
      _(driver[:memory_limit]).must_equal 0
    end
  end

  describe "chef_image default" do
    it "is chef/chef when the provisioner product_name is chef (default)" do
      _(driver[:chef_image]).must_equal "chef/chef"
    end

    it "is cincproject/cinc when the provisioner product_name is cinc" do
      provisioner_config[:product_name] = "cinc"
      _(driver[:chef_image]).must_equal "cincproject/cinc"
    end

    it "respects an explicit override regardless of product_name" do
      provisioner_config[:product_name] = "cinc"
      config[:chef_image]               = "myregistry.example.com/custom-cinc"
      _(driver[:chef_image]).must_equal "myregistry.example.com/custom-cinc"
    end
  end

  describe "#chef_version" do
    it "is whatever the user asked for" do
      config[:chef_version] = "18.4.12"
      _(driver.send(:chef_version)).must_equal "18.4.12"
    end

    # There is no `stable` tag on the chef/chef repo; `latest` is what the
    # stable channel actually publishes to.
    it "maps the stable channel onto the latest tag" do
      config[:chef_version] = "stable"
      _(driver.send(:chef_version)).must_equal "latest"
    end

    it "defaults to latest" do
      _(driver.send(:chef_version)).must_equal "latest"
    end
  end

  describe "#chef_image" do
    it "joins the configured repo and the resolved version" do
      config[:chef_version] = "18"
      _(driver.send(:chef_image)).must_equal "chef/chef:18"
    end
  end

  describe "#chef_container_name" do
    it "uses a chef- prefix when the provisioner product_name is chef (default)" do
      _(driver.send(:chef_container_name)).must_equal "chef-latest"
    end

    it "uses a cinc- prefix when the provisioner product_name is cinc" do
      provisioner_config[:product_name] = "cinc"
      _(driver.send(:chef_container_name)).must_equal "cinc-latest"
    end

    it "appends the platform suffix when set" do
      provisioner_config[:product_name] = "cinc"
      config[:platform]                 = "linux/amd64"
      _(driver.send(:chef_container_name)).must_equal "cinc-latest-linux-amd64"
    end

    it "replaces every slash so a variant platform yields a valid container name" do
      config[:platform] = "linux/amd64/v2"
      _(driver.send(:chef_container_name)).must_equal "chef-latest-linux-amd64-v2"
    end

    it "includes the chef version so two versions can coexist" do
      config[:chef_version] = "17.10.0"
      _(driver.send(:chef_container_name)).must_equal "chef-17.10.0"
    end

    # `platform: ~` in a kitchen.yml yields nil rather than the "" default,
    # and nil is neither empty-string-equal nor tr-able.
    it "treats an explicitly null platform the same as an unset one" do
      config[:platform] = nil
      _(driver.send(:chef_container_name)).must_equal "chef-latest"
    end
  end

  describe "#oci_platform" do
    def oci(platform)
      driver.send(:oci_platform, platform)
    end

    it "passes nil through untouched" do
      _(oci(nil)).must_be_nil
    end

    it "passes an empty platform through untouched" do
      _(oci("")).must_equal ""
    end

    it "passes a bare value with no slash through untouched" do
      _(oci("linux")).must_equal "linux"
    end

    it "converts os/arch to an OCI platform spec" do
      _(JSON.parse(oci("linux/amd64"))).must_equal({ "os" => "linux", "architecture" => "amd64" })
    end

    it "keeps the variant for linux/amd64/v2" do
      _(JSON.parse(oci("linux/amd64/v2"))).must_equal(
        { "os" => "linux", "architecture" => "amd64", "variant" => "v2" }
      )
    end

    it "keeps the variant for linux/arm64/v8" do
      _(JSON.parse(oci("linux/arm64/v8"))).must_equal(
        { "os" => "linux", "architecture" => "arm64", "variant" => "v8" }
      )
    end

    it "omits an empty trailing variant" do
      _(JSON.parse(oci("linux/amd64/"))).must_equal({ "os" => "linux", "architecture" => "amd64" })
    end
  end

  describe "image reference parsing" do
    def parsed(image)
      driver.send(:parse_image_name, image)
    end

    it "defaults an untagged image to the latest tag" do
      _(parsed("almalinux")).must_equal ["almalinux", "latest"]
    end

    it "splits an explicit tag" do
      _(parsed("almalinux:9")).must_equal ["almalinux", "9"]
    end

    it "splits a tag off a namespaced image" do
      _(parsed("dokken/almalinux-8:latest")).must_equal ["dokken/almalinux-8", "latest"]
    end

    it "keeps the registry port with the repo when a tag is present" do
      _(parsed("localhost:5000/almalinux:9")).must_equal ["localhost:5000/almalinux", "9"]
    end

    # "localhost:5000/almalinux" has a colon, but it delimits the registry
    # port, not a tag. Treating it as a tag produced repo "localhost" and tag
    # "5000/almalinux", so every subsequent image lookup pointed nowhere.
    it "keeps the registry port with the repo when no tag is present" do
      _(parsed("localhost:5000/almalinux")).must_equal ["localhost:5000/almalinux", "latest"]
    end

    it "keeps a registry host with a port and a namespaced untagged image together" do
      _(parsed("registry.example.com:5000/org/image")).must_equal ["registry.example.com:5000/org/image", "latest"]
    end

    it "exposes the halves as #repo and #tag" do
      _(driver.send(:repo, "quay.io/org/image:1.2")).must_equal "quay.io/org/image"
      _(driver.send(:tag, "quay.io/org/image:1.2")).must_equal "1.2"
    end

    it "always renders an explicit tag via #short_image_path" do
      _(driver.send(:short_image_path, "almalinux")).must_equal "almalinux:latest"
      _(driver.send(:short_image_path, "localhost:5000/almalinux")).must_equal "localhost:5000/almalinux:latest"
    end

    it "leaves the path alone via #registry_image_path when no registry is configured" do
      _(driver.send(:registry_image_path, "almalinux:9")).must_equal "almalinux:9"
    end

    it "prefixes a configured registry via #registry_image_path" do
      config[:docker_registry] = "registry.example.com"
      _(driver.send(:registry_image_path, "almalinux:9")).must_equal "registry.example.com/almalinux:9"
    end
  end

  describe "#platform_image" do
    it "derives repo:tag from the kitchen platform name" do
      _(driver.send(:platform_image)).must_equal "almalinux:9"
    end

    it "uses a bare platform name with no release as-is" do
      platform.stubs(:name).returns("almalinux")
      _(driver.send(:platform_image)).must_equal "almalinux"
    end

    it "prefers an explicitly configured image" do
      config[:image] = "dokken/almalinux-9:latest"
      _(driver.send(:platform_image)).must_equal "dokken/almalinux-9:latest"
    end
  end

  describe "#work_image" do
    before do
      Dir.stubs(:home).returns("/home/someone")
      FileUtils.stubs(:pwd).returns("/some/project")
    end

    it "is the instance name, which is unique per project and suite" do
      _(driver.send(:work_image)).must_equal driver.send(:instance_name)
    end

    it "is prefixed when image_prefix is configured" do
      config[:image_prefix] = "myorg"
      _(driver.send(:work_image)).must_equal "myorg/#{driver.send(:instance_name)}"
    end

    it "is lowercased, because docker rejects uppercase image names" do
      config[:image_prefix] = "MyOrg"
      _(driver.send(:work_image)).must_equal driver.send(:work_image).downcase
    end
  end

  describe "#work_image_dockerfile" do
    it "builds from the platform image and labels its provenance" do
      dockerfile = driver.send(:work_image_dockerfile)

      _(dockerfile.lines.first.chomp).must_equal "FROM almalinux:9"
      _(dockerfile).must_include "LABEL X-Built-By=kitchen-dokken X-Built-From=almalinux:9"
    end

    it "builds from the configured registry when one is set" do
      config[:docker_registry] = "registry.example.com"

      _(driver.send(:work_image_dockerfile).lines.first.chomp).must_equal "FROM registry.example.com/almalinux:9"
    end

    it "appends each intermediate instruction on its own line" do
      config[:intermediate_instructions] = ["RUN dnf -y install which", "ENV FOO=bar"]

      _(driver.send(:work_image_dockerfile).lines.map(&:chomp).last(2)).must_equal(
        ["RUN dnf -y install which", "ENV FOO=bar"]
      )
    end

    it "tolerates a single instruction given as a bare string" do
      config[:intermediate_instructions] = "RUN true"

      _(driver.send(:work_image_dockerfile)).must_include "RUN true"
    end
  end

  describe "#build_work_image" do
    let(:state) { {} }

    before { offline! }

    it "does not rebuild an image that already exists" do
      ::Docker::Image.stubs(:exist?).returns(true)
      ::Docker::Image.expects(:build).never

      driver.send(:build_work_image, state)

      _(state).must_be_empty
    end

    it "builds the image and records it in state" do
      ::Docker::Image.stubs(:exist?).returns(false)
      ::Docker::Image.expects(:build).returns(FakeImage.new)

      driver.send(:build_work_image, state)

      _(state[:work_image]).must_equal driver.send(:work_image)
    end

    it "explains the common causes when the daemon rejects the build" do
      ::Docker::Image.stubs(:exist?).returns(false)
      ::Docker::Image.stubs(:build).raises(
        ::Docker::Error::UnexpectedResponseError, %({"error":"The command returned a non-zero code: 1"})
      )

      err = _ { driver.send(:build_work_image, state) }.must_raise RuntimeError

      _(err.message).must_include "The command returned a non-zero code: 1"
      _(err.message).must_include "unresponsive mirror"
    end

    # The daemon does not always answer with JSON -- a proxy or a plain-text
    # 500 used to turn into a JSON::ParserError raised from inside the rescue,
    # burying the actual failure.
    it "still reports a build failure when the daemon's response is not JSON" do
      ::Docker::Image.stubs(:exist?).returns(false)
      ::Docker::Image.stubs(:build).raises(::Docker::Error::UnexpectedResponseError, "502 Bad Gateway")

      err = _ { driver.send(:build_work_image, state) }.must_raise RuntimeError

      _(err.message).must_include "work_image build failed"
      _(err.message).must_include "502 Bad Gateway"
    end

    it "wraps any other build error" do
      ::Docker::Image.stubs(:exist?).returns(false)
      ::Docker::Image.stubs(:build).raises(StandardError, "boom")

      err = _ { driver.send(:build_work_image, state) }.must_raise RuntimeError

      _(err.message).must_equal "work_image build failed: boom"
    end
  end

  describe "volumes and binds" do
    before do
      driver.stubs(:remote_docker_host?).returns(false)
      driver.stubs(:running_inside_docker?).returns(false)
      Dir.stubs(:home).returns("/home/someone")
      FileUtils.stubs(:pwd).returns("/some/project")
    end

    it "binds the kitchen and verifier sandboxes for a local daemon" do
      _volumes, binds = driver.send(:calc_volumes_binds)

      _(binds).must_equal [
        "#{driver.send(:dokken_kitchen_sandbox)}:/opt/kitchen",
        "#{driver.send(:dokken_verifier_sandbox)}:/opt/verifier",
      ]
    end

    it "binds the sandbox at the provisioner's root_path" do
      provisioner_config[:root_path] = "/opt/somewhere"

      _volumes, binds = driver.send(:calc_volumes_binds)

      _(binds.first).must_match(%r{:/opt/somewhere\z})
    end

    # A remote daemon cannot see the local filesystem, so the sandbox has to
    # be shipped over ssh into the data container instead of bind-mounted.
    it "binds no sandboxes for a remote daemon" do
      driver.stubs(:remote_docker_host?).returns(true)

      _volumes, binds = driver.send(:calc_volumes_binds)

      _(binds).must_equal []
    end

    it "binds no sandboxes when kitchen itself runs in a container" do
      driver.stubs(:running_inside_docker?).returns(true)

      _volumes, binds = driver.send(:calc_volumes_binds)

      _(binds).must_equal []
    end

    it "splits a host:container volume into a bind" do
      config[:volumes] = ["/data:/data"]

      volumes, binds = driver.send(:calc_volumes_binds)

      _(binds).must_include "/data:/data"
      _(volumes).must_equal({})
    end

    it "keeps an anonymous volume as a volume" do
      config[:volumes] = ["/var/lib/anon"]

      volumes, _binds = driver.send(:calc_volumes_binds)

      _(volumes).must_equal("/var/lib/anon" => {})
    end

    it "carries explicitly configured binds through" do
      config[:binds] = ["/etc/hosts:/etc/hosts:ro"]

      _volumes, binds = driver.send(:calc_volumes_binds)

      _(binds).must_include "/etc/hosts:/etc/hosts:ro"
    end

    it "leaves a hash of volumes alone" do
      config[:volumes] = { "/anon" => {} }

      volumes, _binds = driver.send(:calc_volumes_binds)

      _(volumes).must_equal("/anon" => {})
    end

    it "passes an already-coerced PartialHash straight through" do
      partial = Kitchen::Driver::Dokken::PartialHash["/anon" => {}]
      binds = []

      _(driver.send(:coerce_volumes, partial, binds)).must_be_same_as partial
      _(binds).must_equal []
    end

    it "does not mutate the configured volumes list" do
      config[:volumes] = ["/data:/data", "/anon"]

      driver.send(:calc_volumes_binds)

      _(config[:volumes]).must_equal ["/data:/data", "/anon"]
    end
  end

  describe "Kitchen::Driver::Dokken::PartialHash" do
    let(:partial) { Kitchen::Driver::Dokken::PartialHash["a" => 1] }

    # The daemon echoes back more volumes than we asked for, so equality has
    # to mean "contains what we asked for", not "matches exactly".
    it "equals a hash that contains all of its pairs" do
      _(partial == { "a" => 1, "b" => 2 }).must_equal true
    end

    it "does not equal a hash missing one of its pairs" do
      _(partial == { "b" => 2 }).must_equal false
    end

    it "does not equal a hash with a different value" do
      _(partial == { "a" => 2 }).must_equal false
    end

    it "does not equal a non-hash" do
      _(partial == "a").must_equal false
    end

    it "is empty-equal to anything hash-like" do
      _(Kitchen::Driver::Dokken::PartialHash.new == { "x" => 1 }).must_equal true
    end
  end

  describe "#coerce_tmpfs" do
    def tmpfs(v)
      driver.send(:coerce_tmpfs, v)
    end

    it "passes nil through" do
      _(tmpfs(nil)).must_be_nil
    end

    it "passes a hash through" do
      _(tmpfs("/run" => "rw")).must_equal("/run" => "rw")
    end

    it "splits a path:options string" do
      _(tmpfs(["/run:rw,noexec,size=65536k"])).must_equal("/run" => "rw,noexec,size=65536k")
    end

    it "maps a bare path to empty options" do
      _(tmpfs(["/run"])).must_equal("/run" => "")
    end

    it "keeps commas in the options rather than splitting on them" do
      _(tmpfs(["/tmp:size=1g,mode=1777"])["/tmp"]).must_equal "size=1g,mode=1777"
    end
  end

  describe "#dokken_volumes_from" do
    it "mounts only the chef container for a local daemon" do
      driver.stubs(:remote_docker_host?).returns(false)
      driver.stubs(:running_inside_docker?).returns(false)

      _(driver.send(:dokken_volumes_from)).must_equal ["chef-latest"]
    end

    it "also mounts the data container for a remote daemon" do
      driver.stubs(:remote_docker_host?).returns(true)
      Dir.stubs(:home).returns("/home/someone")
      FileUtils.stubs(:pwd).returns("/some/project")

      _(driver.send(:dokken_volumes_from).last).must_equal "#{driver.send(:instance_name)}-data"
    end
  end

  describe "#data_port_bindings" do
    it "is just the configured port bindings when no ssh port is pinned" do
      config[:ports] = ["8080:80"]

      _(driver.send(:data_port_bindings)).must_equal(
        "80/tcp" => [{ "HostIp" => "0.0.0.0", "HostPort" => "8080" }]
      )
    end

    it "pins the ssh port when data_ssh_port is set" do
      config[:data_ssh_port] = 2222

      _(driver.send(:data_port_bindings)).must_equal(
        "22/tcp" => [{ "HostIp" => "0.0.0.0", "HostPort" => "2222" }]
      )
    end

    it "merges the pinned ssh port with the configured bindings" do
      config[:data_ssh_port] = 2222
      config[:ports] = ["8080:80"]

      _(driver.send(:data_port_bindings).keys.sort).must_equal ["22/tcp", "80/tcp"]
    end
  end

  describe "#add_dns_config" do
    it "adds nothing when neither dns nor dns_search is set" do
      endpoint = {}
      driver.send(:add_dns_config, endpoint)

      _(endpoint).must_equal({})
    end

    it "adds nameservers when dns is set" do
      config[:dns] = ["8.8.8.8"]
      endpoint = {}
      driver.send(:add_dns_config, endpoint)

      _(endpoint).must_equal("DNSConfig" => { "Nameservers" => ["8.8.8.8"] })
    end

    it "adds the search domains when dns_search is set" do
      config[:dns_search] = ["example.com"]
      endpoint = {}
      driver.send(:add_dns_config, endpoint)

      _(endpoint).must_equal("DNSConfig" => { "Search" => ["example.com"] })
    end
  end

  describe "#start_runner_container" do
    let(:state) { {} }

    before do
      offline!
      driver.stubs(:remote_docker_host?).returns(false)
      driver.stubs(:running_inside_docker?).returns(false)
      Dir.stubs(:home).returns("/home/someone")
      FileUtils.stubs(:pwd).returns("/some/project")
    end

    def runner_args
      captured = nil
      driver.stubs(:run_container).with { |args, **_o| captured = args; true }.returns(FakeContainer.new)
      driver.send(:start_runner_container, state)
      captured
    end

    it "runs the locally built work image by its short name" do
      _(runner_args["Image"]).must_equal "#{driver.send(:work_image)}:latest"
    end

    it "word-splits pid_one_command into a Cmd array" do
      _(runner_args["Cmd"]).must_equal ["sh", "-c", "trap exit 0 SIGTERM; while :; do sleep 1; done"]
    end

    it "records the container json in kitchen state" do
      driver.stubs(:run_container).returns(FakeContainer.new(name: "runner"))

      driver.send(:start_runner_container, state)

      _(state[:runner_container]["Name"]).must_equal "/runner"
    end

    it "aliases the hostname on a custom network so sibling containers resolve it" do
      config[:hostname_aliases] = ["web", "app"]

      aliases = runner_args["NetworkingConfig"]["EndpointsConfig"]["dokken"]["Aliases"]

      _(aliases).must_equal %w{dokken web app}
    end

    it "adds no NetworkingConfig on the host network, which has no endpoints" do
      config[:network_mode] = "host"

      _(runner_args).wont_include "NetworkingConfig"
    end

    it "adds no NetworkingConfig on the bridge network" do
      config[:network_mode] = "bridge"

      _(runner_args).wont_include "NetworkingConfig"
    end

    it "omits an empty entrypoint rather than sending a blank one" do
      _(runner_args).wont_include "Entrypoint"
    end

    it "passes a configured entrypoint through" do
      config[:entrypoint] = ["/usr/sbin/init"]

      _(runner_args["Entrypoint"]).must_equal ["/usr/sbin/init"]
    end

    it "sets CgroupnsMode when cgroupns_host is on" do
      config[:cgroupns_host] = true

      _(runner_args["HostConfig"]["CgroupnsMode"]).must_equal "host"
    end

    it "sets UsernsMode when userns_host is on" do
      config[:userns_host] = true

      _(runner_args["HostConfig"]["UsernsMode"]).must_equal "host"
    end

    # A privileged container cannot be namespaced, so the daemon rejects the
    # combination outright; forcing host userns is the only way to honour it.
    it "forces host user namespaces when privileged" do
      config[:privileged] = true

      _(runner_args["HostConfig"]["UsernsMode"]).must_equal "host"
    end

    it "passes cap_add, cap_drop and security_opt as arrays" do
      config[:cap_add] = "SYS_ADMIN"
      config[:cap_drop] = "MKNOD"
      config[:security_opt] = "seccomp=unconfined"

      host_config = runner_args["HostConfig"]

      _(host_config["CapAdd"]).must_equal ["SYS_ADMIN"]
      _(host_config["CapDrop"]).must_equal ["MKNOD"]
      _(host_config["SecurityOpt"]).must_equal ["seccomp=unconfined"]
    end

    it "mounts /opt/chef from the chef volume container" do
      _(runner_args["HostConfig"]["VolumesFrom"]).must_include "chef-latest"
    end

    it "carries the memory limit through" do
      config[:memory_limit] = 512 * 1024 * 1024

      _(runner_args["HostConfig"]["Memory"]).must_equal 536_870_912
    end
  end

  describe "#start_data_container" do
    let(:state) { {} }

    before do
      offline!
      Dir.stubs(:home).returns("/home/someone")
      FileUtils.stubs(:pwd).returns("/some/project")
    end

    def data_args
      captured = nil
      driver.stubs(:run_container).with { |args, **_o| captured = args; true }.returns(FakeContainer.new)
      driver.send(:start_data_container, state)
      captured
    end

    it "names the container after the instance" do
      _(data_args["name"]).must_equal "#{driver.send(:instance_name)}-data"
    end

    # sshd has to be reachable from the host, and bridge is the only network
    # mode where the daemon publishes ports by default.
    it "always attaches the data container to the bridge network" do
      config[:network_mode] = "dokken"

      _(data_args["HostConfig"]["NetworkMode"]).must_equal "bridge"
    end

    it "publishes all ports when no ssh port is pinned" do
      _(data_args["HostConfig"]["PublishAllPorts"]).must_equal true
    end

    it "stops publishing all ports once an ssh port is pinned" do
      config[:data_ssh_port] = 2222

      _(data_args["HostConfig"]["PublishAllPorts"]).must_equal false
    end

    it "records the container json in kitchen state" do
      driver.stubs(:run_container).returns(FakeContainer.new(name: "data"))

      driver.send(:start_data_container, state)

      _(state[:data_container]["Name"]).must_equal "/data"
    end
  end

  describe "which containers get pinned to the platform" do
    before do
      config[:platform] = "linux/arm64/v8"
      # start_runner_container reaches calc_volumes_binds -> remote_docker_host?,
      # which resolves the lazy :docker_info default and issues a live GET /info
      # against the daemon. Keep the unit suite hermetic.
      driver.stubs(:remote_docker_host?).returns(false)
      driver.stubs(:running_inside_docker?).returns(false)
    end

    it "pins the runner container, whose architecture is under test" do
      driver.expects(:run_container).with(anything, platform: "linux/arm64/v8").returns(stub(json: {}))
      driver.send(:start_runner_container, {})
    end

    it "pins the chef volume container, whose /opt/chef is mounted into the runner" do
      driver.stubs(:with_file_lock).yields
      driver.stubs(:docker_connection).returns(stub("connection"))
      ::Docker::Container.stubs(:all).returns([])
      driver.expects(:create_container).with(anything, platform: "linux/arm64/v8").returns(stub(json: {}))
      driver.send(:create_chef_container, {})
    end

    it "does not pin the data container, which only serves files over ssh" do
      driver.expects(:run_container).with { |_args, **opts| opts.empty? }.returns(stub(json: {}))
      driver.send(:start_data_container, {})
    end
  end

  describe "#create_container" do
    let(:args) { { "name" => "runner", "Image" => "img" } }

    before { offline! }

    it "returns the existing container without creating anything" do
      existing = FakeContainer.new(name: "runner")
      ::Docker::Container.expects(:get).with("runner", {}, connection).returns(existing)
      driver.expects(:create_container_for_platform).never

      _(driver.send(:create_container, args)).must_equal existing
    end

    it "creates the container when it does not exist yet" do
      created = FakeContainer.new(name: "runner")
      ::Docker::Container.stubs(:get).raises(::Docker::Error::NotFoundError)
      driver.expects(:create_container_for_platform).returns(created)

      _(driver.send(:create_container, args)).must_equal created
    end

    it "marks the container as a test kitchen container" do
      ::Docker::Container.stubs(:get).raises(::Docker::Error::NotFoundError)
      driver.expects(:create_container_for_platform).with { |a, _p| a["Env"].include?("TEST_KITCHEN=1") }
        .returns(FakeContainer.new)

      driver.send(:create_container, args)
    end

    it "forwards the CI environment variable when kitchen runs in CI" do
      ENV.stubs(:include?).with("CI").returns(true)
      ENV.stubs(:[]).with("CI").returns("true")
      ::Docker::Container.stubs(:get).raises(::Docker::Error::NotFoundError)
      driver.expects(:create_container_for_platform).with { |a, _p| a["Env"].include?("CI=true") }
        .returns(FakeContainer.new)

      driver.send(:create_container, args)
    end

    it "keeps the user's own env vars" do
      args["Env"] = ["FOO=bar"]
      ::Docker::Container.stubs(:get).raises(::Docker::Error::NotFoundError)
      driver.expects(:create_container_for_platform).with { |a, _p| a["Env"].include?("FOO=bar") }
        .returns(FakeContainer.new)

      driver.send(:create_container, args)
    end

    # start_runner_container passes config[:env] straight through, so appending
    # to args["Env"] in place edits the driver's own configuration.
    it "does not mutate the caller's env array" do
      config[:env] = ["FOO=bar"]
      args["Env"] = config[:env]
      ::Docker::Container.stubs(:get).raises(::Docker::Error::NotFoundError)
      driver.stubs(:create_container_for_platform).returns(FakeContainer.new)

      driver.send(:create_container, args)

      _(config[:env]).must_equal ["FOO=bar"]
    end

    # Retrying the create used to re-run the env-stamping lines against the
    # same array, so the daemon received TEST_KITCHEN=1 once per attempt.
    it "stamps TEST_KITCHEN=1 exactly once even when the create is retried" do
      config[:api_retries] = 2
      ::Docker::Container.stubs(:get).raises(::Docker::Error::NotFoundError)

      seen = []
      driver.stubs(:create_container_for_platform).with do |a, _p|
        seen << a["Env"].dup
        raise ::Docker::Error::TimeoutError
      end

      _ { driver.send(:create_container, args) }.must_raise RuntimeError

      _(seen).wont_be_empty
      seen.each { |env| _(env.count("TEST_KITCHEN=1")).must_equal 1 }
    end

    it "falls back to fetching the container when the create loses a race" do
      winner = FakeContainer.new(name: "runner")
      ::Docker::Container.stubs(:get)
        .raises(::Docker::Error::NotFoundError)
        .then.returns(winner)
      driver.stubs(:create_container_for_platform).raises(::Docker::Error::ConflictError)

      _(driver.send(:create_container, args)).must_equal winner
    end

    it "reports which container it could not create" do
      ::Docker::Container.stubs(:get).raises(::Docker::Error::NotFoundError)
      driver.stubs(:create_container_for_platform).raises(::Docker::Error::ClientError, "bad request")

      err = _ { driver.send(:create_container, args) }.must_raise RuntimeError

      _(err.message).must_include "runner"
    end
  end

  describe "#create_container_for_platform" do
    let(:args) { { "name" => "dokken-test", "Image" => "almalinux:9", "Cmd" => ["true"] } }

    before do
      driver.stubs(:docker_connection).returns(connection)
    end

    it "uses Docker::Container.create when no platform is given" do
      ::Docker::Container.expects(:create).with(args, connection).returns(:container)
      _(driver.send(:create_container_for_platform, args, nil)).must_equal :container
    end

    it "uses Docker::Container.create when the platform is empty" do
      ::Docker::Container.expects(:create).with(args, connection).returns(:container)
      _(driver.send(:create_container_for_platform, args, "")).must_equal :container
    end

    it "posts platform as a query parameter, not as a body key" do
      connection.expects(:post).with(
        "/containers/create",
        { "name" => "dokken-test", "platform" => "linux/amd64/v2" },
        { body: JSON.dump("Image" => "almalinux:9", "Cmd" => ["true"]) }
      ).returns('{"Id":"deadbeef"}')
      ::Docker::Container.expects(:get).with("dokken-test", {}, connection).returns(:container)

      _(driver.send(:create_container_for_platform, args, "linux/amd64/v2")).must_equal :container
    end
  end

  describe "platform forwarding through the whole create chain" do
    let(:created) { FakeContainer.new(name: "runner") }

    before do
      driver.stubs(:docker_connection).returns(connection)
      driver.stubs(:wait_running_state)
    end

    # Guards the two kwarg hand-offs that the call-site tests above cannot see:
    # run_container -> create_container -> create_container_for_platform.
    it "carries the platform from run_container down to the create query" do
      ::Docker::Container.stubs(:get).raises(::Docker::Error::NotFoundError).then.returns(created)
      connection.expects(:post).with do |path, query, opts|
        body = JSON.parse(opts[:body])
        path == "/containers/create" &&
          query == { "name" => "runner", "platform" => "linux/arm64/v8" } &&
          !body.key?("name") &&
          body["Image"] == "img"
      end.returns('{"Id":"deadbeef"}')

      driver.send(:run_container, { "name" => "runner", "Image" => "img" }, platform: "linux/arm64/v8")
    end
  end

  describe "#run_container" do
    let(:container) { FakeContainer.new(name: "runner") }

    before do
      offline!
      driver.stubs(:wait_running_state)
    end

    it "creates, starts and returns the container" do
      driver.stubs(:create_container).returns(container)
      ::Docker::Container.stubs(:get).returns(container)

      _(driver.send(:run_container, { "name" => "runner" })).must_equal container
      _(container.start_count).must_equal 1
    end

    it "waits for the container to reach the running state" do
      driver.stubs(:create_container).returns(container)
      ::Docker::Container.stubs(:get).returns(container)
      driver.expects(:wait_running_state).with("runner", true)

      driver.send(:run_container, { "name" => "runner" })
    end
  end

  describe "#wait_running_state" do
    before { offline! }

    it "returns as soon as the container reports the wanted state" do
      running = FakeContainer.new(name: "runner")
      ::Docker::Container.expects(:get).once.returns(running)

      driver.send(:wait_running_state, "runner", true)
    end

    it "polls until the container reaches the wanted state" do
      stopped = FakeContainer.new(
        name: "runner",
        info: { "State" => { "Running" => false, "FinishedAt" => "0001-01-01T00:00:00Z" } }
      )
      running = FakeContainer.new(name: "runner")
      ::Docker::Container.stubs(:get).returns(stopped).then.returns(running)

      driver.send(:wait_running_state, "runner", true)
    end

    it "gives up rather than polling forever" do
      stuck = FakeContainer.new(
        name: "runner",
        info: { "State" => { "Running" => false, "FinishedAt" => "0001-01-01T00:00:00Z" } }
      )
      ::Docker::Container.stubs(:get).returns(stuck)

      driver.send(:wait_running_state, "runner", true)
    end

    it "stops waiting once the container has actually finished" do
      finished = FakeContainer.new(
        name: "runner",
        info: { "State" => { "Running" => false, "FinishedAt" => "2026-01-01T00:00:00Z" } }
      )
      ::Docker::Container.expects(:get).once.returns(finished)

      driver.send(:wait_running_state, "runner", true)
    end
  end

  describe "stopping and deleting" do
    before { offline! }

    it "stops a container and waits for it to leave the running state" do
      container = FakeContainer.new(name: "runner")
      ::Docker::Container.stubs(:get).returns(container)
      driver.stubs(:wait_running_state)

      driver.send(:stop_container, "runner")

      _(container.stop_args).must_equal [{ force: false }]
    end

    it "is a no-op to stop a container that is already gone" do
      ::Docker::Container.stubs(:get).raises(::Docker::Error::NotFoundError)

      driver.send(:stop_container, "runner")
    end

    it "force-deletes a container along with its volumes" do
      container = FakeContainer.new(name: "runner")
      ::Docker::Container.stubs(:get).returns(container)

      driver.send(:delete_container, "runner")

      _(container.delete_args).must_equal [{ force: true, v: true }]
    end

    it "is a no-op to delete a container that is already gone" do
      ::Docker::Container.stubs(:get).raises(::Docker::Error::NotFoundError)

      driver.send(:delete_container, "runner")
    end

    it "force-removes an image" do
      image = FakeImage.new
      ::Docker::Image.stubs(:get).returns(image)

      driver.send(:delete_image, "someimage")

      _(image.remove_args).must_equal [{ force: true }]
    end

    it "says so rather than raising when the image is already gone" do
      ::Docker::Image.stubs(:get).raises(::Docker::Error::NotFoundError)

      driver.send(:delete_image, "someimage")
    end

    it "does not try to remove a work image that does not exist" do
      ::Docker::Image.stubs(:exist?).returns(false)
      ::Docker::Image.expects(:get).never

      driver.send(:delete_work_image)
    end

    it "keeps going when another container still depends on the work image" do
      image = FakeImage.new
      ::Docker::Image.stubs(:exist?).returns(true)
      ::Docker::Image.stubs(:get).returns(image)
      image.stubs(:remove).raises(::Docker::Error::ConflictError)

      driver.send(:delete_work_image)
    end
  end

  describe "#docker_connection" do
    it "applies the configured timeouts to the docker client options" do
      config[:read_timeout] = 60
      config[:write_timeout] = 90
      ::Docker::Connection.expects(:new).with { |_url, opts| opts[:read_timeout] == 60 && opts[:write_timeout] == 90 }
        .returns(:conn)

      _(driver.send(:docker_connection)).must_equal :conn
    end

    it "is memoised, so every call shares one connection" do
      ::Docker::Connection.expects(:new).once.returns(:conn)

      driver.send(:docker_connection)
      driver.send(:docker_connection)
    end
  end

  describe "the named stop and delete helpers" do
    before do
      Dir.stubs(:home).returns("/home/someone")
      FileUtils.stubs(:pwd).returns("/some/project")
    end

    it "stops the runner by name" do
      driver.expects(:stop_container).with(driver.send(:instance_name))
      driver.send(:stop_runner_container)
    end

    it "stops the data container by name" do
      driver.expects(:stop_container).with("#{driver.send(:instance_name)}-data")
      driver.send(:stop_data_container)
    end

    it "deletes the runner by name" do
      driver.expects(:delete_container).with(driver.send(:instance_name))
      driver.send(:delete_runner_container)
    end

    it "deletes the data container by name" do
      driver.expects(:delete_container).with("#{driver.send(:instance_name)}-data")
      driver.send(:delete_data_container)
    end

    it "deletes the shared chef container by name" do
      driver.expects(:delete_container).with("chef-latest")
      driver.send(:delete_chef_container)
    end
  end

  describe "#container_exist?" do
    before { offline! }

    it "is true when the daemon knows the container" do
      ::Docker::Container.stubs(:get).returns(FakeContainer.new)

      _(driver.send(:container_exist?, "runner")).must_equal true
    end

    it "is false when the daemon does not" do
      ::Docker::Container.stubs(:get).raises(::Docker::Error::NotFoundError)

      _(driver.send(:container_exist?, "runner")).must_equal false
    end
  end

  describe "#with_retries" do
    before { driver.stubs(:sleep) }

    it "returns the block's value when it succeeds first time" do
      _(driver.send(:with_retries) { :ok }).must_equal :ok
    end

    it "retries a transient docker error" do
      attempts = 0

      result = driver.send(:with_retries) do
        attempts += 1
        raise ::Docker::Error::TimeoutError if attempts < 3

        :ok
      end

      _(result).must_equal :ok
      _(attempts).must_equal 3
    end

    it "gives up after api_retries attempts" do
      config[:api_retries] = 3
      attempts = 0

      _ do
        driver.send(:with_retries) do
          attempts += 1
          raise ::Docker::Error::IOError
        end
      end.must_raise ::Docker::Error::IOError

      _(attempts).must_equal 3
    end

    it "does not retry an error that retrying cannot fix" do
      attempts = 0

      _ do
        driver.send(:with_retries) do
          attempts += 1
          raise ::Docker::Error::NotFoundError
        end
      end.must_raise ::Docker::Error::NotFoundError

      _(attempts).must_equal 1
    end
  end

  describe "#make_dokken_network" do
    before do
      offline!
      stub_home!
      driver.stubs(:with_file_lock).yields
    end

    it "does nothing when the user picked another network" do
      config[:network_mode] = "bridge"
      ::Docker::Network.expects(:get).never

      driver.send(:make_dokken_network)
    end

    it "leaves an existing dokken network alone" do
      ::Docker::Network.expects(:get).with("dokken", {}, connection).returns(stub)
      ::Docker::Network.expects(:create).never

      driver.send(:make_dokken_network)
    end

    it "creates the network when it is missing" do
      ::Docker::Network.stubs(:get).raises(::Docker::Error::NotFoundError)
      ::Docker::Network.expects(:create).with { |name, settings| name == "dokken" && settings == {} }.returns(stub)

      driver.send(:make_dokken_network)
    end

    it "creates an ipv6 network with the configured subnet" do
      config[:ipv6] = true
      ::Docker::Network.stubs(:get).raises(::Docker::Error::NotFoundError)
      ::Docker::Network.expects(:create).with do |name, settings|
        name == "dokken" &&
          settings == { "EnableIPv6" => true, "IPAM" => { "Config" => [{ "Subnet" => "2001:db8:1::/64" }] } }
      end.returns(stub)

      driver.send(:make_dokken_network)
    end

    # Several kitchen instances converge in parallel and all race to create
    # the one shared network; losing that race is not an error.
    it "swallows a create that lost the race to another instance" do
      ::Docker::Network.stubs(:get).raises(::Docker::Error::NotFoundError)
      ::Docker::Network.stubs(:create).raises(::Docker::Error::ConflictError)

      driver.send(:make_dokken_network)
    end
  end

  describe "#create_chef_container" do
    let(:state) { {} }

    before do
      offline!
      stub_home!
      driver.stubs(:with_file_lock).yields
    end

    it "reuses an existing chef container" do
      ::Docker::Container.stubs(:all).returns([stub(info: { "Names" => ["/chef-latest"] })])
      driver.expects(:create_container).never

      driver.send(:create_chef_container, state)

      _(state).must_be_empty
    end

    it "creates the volume container from the chef image" do
      ::Docker::Container.stubs(:all).returns([])
      driver.expects(:create_container).with do |args, platform:|
        args["name"] == "chef-latest" && args["Cmd"] == ["true"] &&
          args["Image"] == "chef/chef:latest" && platform == ""
      end.returns(FakeContainer.new(name: "chef-latest"))

      driver.send(:create_chef_container, state)

      _(state[:chef_container]["Name"]).must_equal "/chef-latest"
    end

    it "reports which chef container it could not create" do
      ::Docker::Container.stubs(:all).returns([])
      driver.stubs(:create_container).raises(StandardError, "nope")

      err = _ { driver.send(:create_chef_container, state) }.must_raise RuntimeError

      _(err.message).must_include "chef-latest"
    end
  end

  describe "#with_file_lock" do
    it "yields with an exclusive lock and cleans up the handle" do
      path = File.join(stub_home!, "dokken.lock")
      yielded = false

      driver.send(:with_file_lock, path) { yielded = true }

      _(yielded).must_equal true
      _(File.exist?(path)).must_equal true
    end
  end

  describe "pulling images" do
    before { offline! }

    it "always pulls the platform image by default" do
      driver.expects(:pull_image).with("almalinux:9")

      driver.send(:pull_platform_image)
    end

    it "only pulls a missing platform image when pull_platform_image is off" do
      config[:pull_platform_image] = false
      ::Docker::Image.stubs(:exist?).returns(true)
      driver.expects(:pull_image).never

      driver.send(:pull_platform_image)
    end

    it "pulls a missing platform image even when pull_platform_image is off" do
      config[:pull_platform_image] = false
      ::Docker::Image.stubs(:exist?).returns(false)
      driver.expects(:pull_image).with("almalinux:9")

      driver.send(:pull_platform_image)
    end

    it "always pulls the chef image by default" do
      driver.expects(:pull_image).with("chef/chef:latest")

      driver.send(:pull_chef_image)
    end

    it "only pulls a missing chef image when pull_chef_image is off" do
      config[:pull_chef_image] = false
      ::Docker::Image.stubs(:exist?).returns(true)
      driver.expects(:pull_image).never

      driver.send(:pull_chef_image)
    end

    it "asks the daemon for the fully qualified path and the configured platform" do
      config[:platform] = "linux/arm64"
      ::Docker::Image.stubs(:exist?).returns(false)
      ::Docker::Image.expects(:create).with(
        { "fromImage" => "almalinux:9", "platform" => "linux/arm64" },
        {},
        connection
      ).returns(FakeImage.new)

      driver.send(:pull_image, "almalinux:9")
    end

    it "reports true when the pulled image differs from what was there before" do
      ::Docker::Image.stubs(:exist?).returns(true)
      ::Docker::Image.stubs(:get).returns(FakeImage.new(id: "sha256:old"))
      ::Docker::Image.stubs(:create).returns(FakeImage.new(id: "sha256:new"))

      _(driver.send(:pull_image, "almalinux:9")).must_equal true
    end

    it "reports false when the pull was a no-op" do
      ::Docker::Image.stubs(:exist?).returns(true)
      ::Docker::Image.stubs(:get).returns(FakeImage.new(id: "sha256:same"))
      ::Docker::Image.stubs(:create).returns(FakeImage.new(id: "sha256:same"))

      _(driver.send(:pull_image, "almalinux:9")).must_equal false
    end
  end

  describe "#make_data_image" do
    before do
      offline!
      scratch = stub_home!
      Dir.stubs(:tmpdir).returns(scratch)
    end

    it "does not rebuild the data image when it already exists" do
      ::Docker::Image.stubs(:exist?).returns(true)
      ::Docker::Image.expects(:build_from_dir).never

      driver.send(:make_data_image)
    end

    it "writes a Dockerfile and the authorized key, then builds and tags" do
      ::Docker::Image.stubs(:exist?).returns(false)
      image = FakeImage.new
      ::Docker::Image.expects(:build_from_dir).with(
        "#{tmphome}/dokken", "nocache" => true, "rm" => true
      ).returns(image)

      driver.send(:make_data_image)

      _(File.read("#{tmphome}/dokken/Dockerfile")).must_include "FROM almalinux:9"
      _(File.read("#{tmphome}/dokken/authorized_keys")).must_match(/\Assh-rsa /)
      _(image.tag_args).must_equal [{ "repo" => "dokken/kitchen-cache", "tag" => "latest", "force" => true }]
    end

    it "builds the data image from the configured registry" do
      config[:docker_registry] = "registry.example.com"
      ::Docker::Image.stubs(:exist?).returns(false)
      ::Docker::Image.stubs(:build_from_dir).returns(FakeImage.new)

      driver.send(:make_data_image)

      _(File.read("#{tmphome}/dokken/Dockerfile")).must_include "FROM registry.example.com/almalinux:9"
    end
  end

  describe "#save_misc_state" do
    before do
      Dir.stubs(:home).returns("/home/someone")
      FileUtils.stubs(:pwd).returns("/some/project")
    end

    it "records everything the transport and provisioner need later" do
      state = {}
      driver.send(:save_misc_state, state)

      _(state[:platform_image]).must_equal "almalinux:9"
      _(state[:instance_name]).must_equal driver.send(:instance_name)
      _(state[:instance_platform_name]).must_equal "almalinux-9"
      _(state[:image_prefix]).must_be_nil
    end
  end

  describe "#create" do
    let(:state) { {} }

    before do
      %i{
        authenticate! pull_platform_image make_dokken_network pull_chef_image
        create_chef_container dokken_create_sandbox make_data_image
        start_data_container build_work_image start_runner_container save_misc_state
      }.each { |m| driver.stubs(m) }
    end

    it "does not build a data container for a local daemon" do
      driver.stubs(:remote_docker_host?).returns(false)
      driver.stubs(:running_inside_docker?).returns(false)
      driver.expects(:make_data_image).never
      driver.expects(:start_data_container).never

      driver.create(state)
    end

    it "builds a data container for a remote daemon" do
      driver.stubs(:remote_docker_host?).returns(true)
      driver.expects(:make_data_image)
      driver.expects(:start_data_container).with(state)

      driver.create(state)
    end

    it "builds a data container when kitchen itself runs in a container" do
      driver.stubs(:remote_docker_host?).returns(false)
      driver.stubs(:running_inside_docker?).returns(true)
      driver.expects(:start_data_container).with(state)

      driver.create(state)
    end

    it "authenticates before pulling anything" do
      driver.stubs(:remote_docker_host?).returns(false)
      driver.stubs(:running_inside_docker?).returns(false)
      order = sequence("create")
      driver.expects(:authenticate!).in_sequence(order)
      driver.expects(:pull_platform_image).in_sequence(order)
      driver.expects(:pull_chef_image).in_sequence(order)

      driver.create(state)
    end

    it "starts the runner only after its work image has been built" do
      driver.stubs(:remote_docker_host?).returns(false)
      driver.stubs(:running_inside_docker?).returns(false)
      order = sequence("create")
      driver.expects(:build_work_image).in_sequence(order)
      driver.expects(:start_runner_container).in_sequence(order)

      driver.create(state)
    end
  end

  describe "#destroy" do
    before do
      %i{
        stop_data_container delete_data_container stop_runner_container
        delete_runner_container delete_work_image dokken_delete_sandbox
      }.each { |m| driver.stubs(m) }
    end

    it "tears down the runner, its image and the sandbox" do
      driver.stubs(:remote_docker_host?).returns(false)
      driver.stubs(:running_inside_docker?).returns(false)
      driver.expects(:stop_runner_container)
      driver.expects(:delete_runner_container)
      driver.expects(:delete_work_image)
      driver.expects(:dokken_delete_sandbox)

      driver.destroy({})
    end

    it "leaves the data container alone for a local daemon, which never had one" do
      driver.stubs(:remote_docker_host?).returns(false)
      driver.stubs(:running_inside_docker?).returns(false)
      driver.expects(:stop_data_container).never
      driver.expects(:delete_data_container).never

      driver.destroy({})
    end

    it "tears down the data container for a remote daemon" do
      driver.stubs(:remote_docker_host?).returns(true)
      driver.expects(:stop_data_container)
      driver.expects(:delete_data_container)

      driver.destroy({})
    end

    # The chef volume container is shared by every instance using the same
    # chef version, so destroying one instance must not remove it.
    it "leaves the shared chef volume container in place" do
      driver.stubs(:remote_docker_host?).returns(false)
      driver.stubs(:running_inside_docker?).returns(false)
      driver.expects(:delete_chef_container).never

      driver.destroy({})
    end
  end

  describe "#image_registry_host" do
    it "is nil for a bare Docker Hub official image" do
      _(driver.send(:image_registry_host, "almalinux:9")).must_be_nil
    end

    it "is nil for a Docker Hub user image, which is not a registry" do
      _(driver.send(:image_registry_host, "dokken/almalinux-8:latest")).must_be_nil
    end

    it "is the host when the first component contains a dot" do
      _(driver.send(:image_registry_host, "quay.io/almalinuxorg/almalinux:10")).must_equal "quay.io"
    end

    it "is the host when the first component contains a port" do
      _(driver.send(:image_registry_host, "localhost:5000/almalinux:9")).must_equal "localhost:5000"
    end

    it "is the host for a bare localhost registry" do
      _(driver.send(:image_registry_host, "localhost/almalinux:9")).must_equal "localhost"
    end
  end

  describe "#docker_config_creds" do
    before { Dir.stubs(:home).returns(tmphome) }

    def write_docker_config(contents)
      FileUtils.mkdir_p(File.join(tmphome, ".docker"))
      File.write(File.join(tmphome, ".docker", "config.json"), JSON.dump(contents))
    end

    it "is empty when there is no config.json" do
      _(driver.send(:docker_config_creds)).must_equal({})
    end

    it "decodes a basic auth entry" do
      write_docker_config("auths" => { "quay.io" => { "auth" => Base64.strict_encode64("user:secret") } })

      _(driver.send(:docker_config_creds)["quay.io"]).must_equal(
        serveraddress: "quay.io", username: "user", password: "secret"
      )
    end

    # A colon is legal in a registry password -- Docker's own tokens routinely
    # contain them -- and splitting on every colon silently truncated it, so
    # the pull failed with an unhelpful 401.
    it "keeps a password that contains a colon intact" do
      write_docker_config("auths" => { "quay.io" => { "auth" => Base64.strict_encode64("user:se:cr:et") } })

      _(driver.send(:docker_config_creds)["quay.io"][:password]).must_equal "se:cr:et"
    end

    it "skips an entry with no auth token" do
      write_docker_config("auths" => { "quay.io" => {} })

      _(driver.send(:docker_config_creds)).must_equal({})
    end

    it "wraps a credential helper in a lazily invoked proc" do
      write_docker_config("credHelpers" => { "quay.io" => "ecr-login" })
      driver.stubs(:`).returns(JSON.dump("ServerURL" => "quay.io", "Username" => "u", "Secret" => "s"))

      helper = driver.send(:docker_config_creds)["quay.io"]

      _(helper).must_respond_to :call
      _(helper.call).must_equal(serveraddress: "quay.io", username: "u", password: "s")
    end

    it "reads the file only once" do
      write_docker_config("auths" => { "quay.io" => { "auth" => Base64.strict_encode64("u:p") } })
      driver.send(:docker_config_creds)
      JSON.expects(:load_file!).never

      driver.send(:docker_config_creds)
    end
  end

  describe "#authenticate!" do
    it "does not authenticate when no creds_file is configured" do
      ::Docker.expects(:authenticate!).never

      driver.send(:authenticate!)
    end

    it "authenticates with the contents of creds_file" do
      path = File.join(stub_home!, "creds.json")
      File.write(path, JSON.dump("username" => "u", "password" => "p"))
      config[:creds_file] = path
      ::Docker.expects(:authenticate!).with { |creds| creds == { "username" => "u", "password" => "p" } }

      driver.send(:authenticate!)
    end
  end

  describe "#docker_creds_for_image" do
    let(:hub_creds)  { { serveraddress: "https://index.docker.io/v1/", username: "hub", password: "hub-secret" } }
    let(:quay_creds) { { serveraddress: "quay.io", username: "quay", password: "quay-secret" } }
    let(:hub_only)   { { "https://index.docker.io/v1/" => hub_creds } }

    def creds_for(image, config_creds)
      driver.stubs(:docker_config_creds).returns(config_creds)
      driver.send(:docker_creds_for_image, image)
    end

    it "defaults docker_config_creds to true so ~/.docker/config.json is still read" do
      _(driver[:docker_config_creds]).must_equal true
    end

    it "uses the Docker Hub entry for an unqualified Hub image" do
      _(creds_for("dokken/almalinux-8:latest", hub_only)).must_equal hub_creds
    end

    it "uses the Docker Hub entry for a docker.io-qualified image" do
      _(creds_for("docker.io/library/almalinux:9", hub_only)).must_equal hub_creds
    end

    it "sends no credentials to another registry when only Docker Hub is configured" do
      _(creds_for("quay.io/almalinuxorg/almalinux:10", hub_only)).must_equal({})
    end

    # docker-api treats a nil creds argument as "use the process-global
    # ::Docker.creds", which authenticate! populates from creds_file. Returning
    # an empty hash is what actually makes the pull anonymous.
    it "never returns nil, which docker-api would resolve to the global creds" do
      _(creds_for("quay.io/almalinuxorg/almalinux:10", hub_only)).wont_be_nil
    end

    it "uses the matching entry when the image's registry is configured" do
      _(creds_for("quay.io/almalinuxorg/almalinux:10", hub_only.merge("quay.io" => quay_creds))).must_equal quay_creds
    end

    it "matches a registry entry that was written as a URL" do
      _(creds_for("quay.io/almalinuxorg/almalinux:10", { "https://quay.io/" => quay_creds })).must_equal quay_creds
    end

    it "matches a localhost registry with a port" do
      local = { serveraddress: "localhost:5000", username: "local", password: "local-secret" }
      _(creds_for("localhost:5000/almalinux:9", { "localhost:5000" => local })).must_equal local
    end

    it "resolves credential helper entries by calling them" do
      _(creds_for("quay.io/almalinuxorg/almalinux:10", { "quay.io" => proc { quay_creds } })).must_equal quay_creds
    end

    it "resolves credential helper entries for Docker Hub images" do
      _(creds_for("dokken/almalinux-8:latest", { "index.docker.io" => proc { hub_creds } })).must_equal hub_creds
    end

    it "prefers creds_file over ~/.docker/config.json when it is set" do
      config[:creds_file] = "/path/to/creds.json"
      driver.stubs(:docker_creds).returns(quay_creds)
      _(driver.send(:docker_creds_for_image, "quay.io/almalinuxorg/almalinux:10")).must_equal quay_creds
    end

    it "skips ~/.docker/config.json entirely when docker_config_creds is false" do
      config[:docker_config_creds] = false
      _(creds_for("dokken/almalinux-8:latest", hub_only)).must_equal({})
    end

    # A stale "docker.io" entry alongside the canonical key must not win just
    # because it happens to be listed first.
    it "prefers the canonical Docker Hub key regardless of config.json order" do
      stale = { serveraddress: "docker.io", username: "stale", password: "stale-secret" }
      ordered = { "docker.io" => stale, "https://index.docker.io/v1/" => hub_creds }
      _(creds_for("dokken/almalinux-8:latest", ordered)).must_equal hub_creds

      reversed = { "https://index.docker.io/v1/" => hub_creds, "docker.io" => stale }
      _(creds_for("dokken/almalinux-8:latest", reversed)).must_equal hub_creds
    end
  end

  describe "#parse_registry_host" do
    it "strips an https scheme" do
      _(driver.send(:parse_registry_host, "https://index.docker.io/v1/")).must_equal "index.docker.io"
    end

    it "strips an http scheme" do
      _(driver.send(:parse_registry_host, "http://localhost:5000/")).must_equal "localhost:5000"
    end

    it "leaves a bare host alone" do
      _(driver.send(:parse_registry_host, "quay.io")).must_equal "quay.io"
    end
  end
end
