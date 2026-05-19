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
  end
end
