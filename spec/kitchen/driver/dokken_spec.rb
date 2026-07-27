require_relative "../../spec_helper"

require "kitchen/driver/dokken"

describe Kitchen::Driver::Dokken do
  let(:logged_output)     { StringIO.new }
  let(:logger)            { Logger.new(logged_output) }
  let(:platform)          { stub(name: "almalinux-9", os_type: nil) }
  let(:suite)             { stub(name: "default") }
  let(:transport)         { stub }
  let(:provisioner_config) { {} }
  let(:provisioner)        { provisioner_config }

  let(:instance) do
    stub(
      name: "default-almalinux-9",
      logger: logger,
      suite: suite,
      platform: platform,
      transport: transport,
      provisioner: provisioner
    )
  end

  let(:config) { {} }

  let(:driver) do
    Kitchen::Driver::Dokken.new(config).finalize_config!(instance)
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

  describe "#create_container_for_platform" do
    let(:args) { { "name" => "dokken-test", "Image" => "almalinux:9", "Cmd" => ["true"] } }
    let(:connection) { stub("connection") }

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

  describe "platform forwarding through the whole create chain" do
    let(:connection) { stub("connection") }
    let(:created)    { stub("container", start: nil) }

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
end
