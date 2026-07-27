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
end
