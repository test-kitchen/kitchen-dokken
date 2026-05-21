require_relative "../../spec_helper"

require "kitchen/provisioner/dokken"

describe Kitchen::Provisioner::Dokken do
  let(:logged_output) { StringIO.new }
  let(:logger)        { Logger.new(logged_output) }
  let(:platform)      { stub(os_type: nil) }
  let(:suite)         { stub(name: "default") }
  let(:driver_config) { { chef_version: "latest" } }
  let(:driver)        { driver_config }

  let(:instance) do
    stub(
      name: "default-almalinux-9",
      logger: logger,
      suite: suite,
      platform: platform,
      driver: driver
    )
  end

  let(:config) { { kitchen_root: "/rooty", test_base_path: "/basist" } }

  let(:provisioner) do
    Kitchen::Provisioner::Dokken.new(config).finalize_config!(instance)
  end

  describe "product_name" do
    it "defaults to chef" do
      _(provisioner[:product_name]).must_equal "chef"
    end

    it "can be set to cinc" do
      config[:product_name] = "cinc"
      _(provisioner[:product_name]).must_equal "cinc"
    end
  end

  describe "chef_binary default" do
    it "is the chef-client path when product_name is chef" do
      _(provisioner[:chef_binary]).must_equal "/opt/chef/bin/chef-client"
    end

    it "is the cinc-client path when product_name is cinc" do
      config[:product_name] = "cinc"
      _(provisioner[:chef_binary]).must_equal "/opt/cinc/bin/cinc-client"
    end

    it "respects an explicit override" do
      config[:product_name] = "cinc"
      config[:chef_binary]  = "/usr/local/bin/cinc-client"
      _(provisioner[:chef_binary]).must_equal "/usr/local/bin/cinc-client"
    end
  end

  describe "#check_license" do
    let(:acceptor) { mock }

    before do
      LicenseAcceptance::Acceptor.stubs(:new).returns(acceptor)
    end

    it "returns without prompting when product is cinc" do
      config[:product_name] = "cinc"
      acceptor.expects(:license_required?).with("cinc", "latest").returns(false)
      acceptor.expects(:check_and_persist).never

      provisioner.check_license
    end

    it "performs the license check when product is chef and a license is required" do
      acceptor.expects(:license_required?).with("chef", "latest").returns(true)
      acceptor.expects(:id_from_mixlib).with("chef").returns("chef")
      acceptor.expects(:check_and_persist).with("chef", "latest")
      acceptor.stubs(:acceptance_value).returns("accept-no-persist")

      provisioner.check_license
      _(provisioner[:chef_license]).must_equal "accept-no-persist"
    end

    it "skips the check when product is chef but no license is required" do
      acceptor.expects(:license_required?).with("chef", "latest").returns(false)
      acceptor.expects(:check_and_persist).never

      provisioner.check_license
    end

    # Helper: patch the parent's check_license to a sentinel so we can
    # verify our override delegated via super, then restore it.
    def with_stubbed_super
      parent = Kitchen::Provisioner::ChefInfra
      original = parent.instance_method(:check_license)
      parent.define_method(:check_license) { :super_called }
      begin
        yield
      ensure
        parent.define_method(:check_license, original)
      end
    end

    it "delegates to super when the parent doesn't define license_acceptance_id (kitchen-cinc parent)" do
      # Simulate the kitchen-cinc rebinding where ChefInfra is an alias for
      # CincInfra and license_acceptance_id is not defined.
      provisioner.stubs(:respond_to?).with(any_parameters).returns(true)
      provisioner.stubs(:respond_to?).with(:license_acceptance_id, true).returns(false)

      with_stubbed_super do
        _(provisioner.check_license).must_equal :super_called
      end
    end

    it "delegates to super when LicenseAcceptance is not loaded (partial cinc shim)" do
      # Simulate a partial kitchen-cinc drop-in shim: license_acceptance_id
      # exists but the LicenseAcceptance constant isn't autoloaded — our body
      # would crash on Acceptor.new, so the guard must delegate instead.
      stash = LicenseAcceptance
      Object.send(:remove_const, :LicenseAcceptance)
      begin
        with_stubbed_super do
          _(provisioner.check_license).must_equal :super_called
        end
      ensure
        Object.const_set(:LicenseAcceptance, stash)
      end
    end
  end
end
