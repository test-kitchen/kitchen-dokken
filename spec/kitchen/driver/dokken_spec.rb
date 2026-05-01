require_relative "../../spec_helper"

require "kitchen/driver/dokken"

describe Kitchen::Driver::Dokken do
  let(:logged_output) { StringIO.new }
  let(:logger)        { Logger.new(logged_output) }
  let(:platform)      { stub(name: "almalinux-9", os_type: nil) }
  let(:suite)         { stub(name: "default") }
  let(:transport)     { stub }
  let(:provisioner)   { stub }

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

  describe "product_name" do
    it "defaults to chef" do
      _(driver[:product_name]).must_equal "chef"
    end

    it "can be overridden" do
      config[:product_name] = "cinc"
      _(driver[:product_name]).must_equal "cinc"
    end
  end

  describe "chef_image default" do
    it "is chef/chef when product_name is chef" do
      _(driver[:chef_image]).must_equal "chef/chef"
    end

    it "is cincproject/cinc when product_name is cinc" do
      config[:product_name] = "cinc"
      _(driver[:chef_image]).must_equal "cincproject/cinc"
    end

    it "respects an explicit override regardless of product_name" do
      config[:product_name] = "cinc"
      config[:chef_image]   = "myregistry.example.com/custom-cinc"
      _(driver[:chef_image]).must_equal "myregistry.example.com/custom-cinc"
    end
  end

  describe "#chef_container_name" do
    it "uses a chef- prefix for the chef product" do
      _(driver.send(:chef_container_name)).must_equal "chef-latest"
    end

    it "uses a cinc- prefix for the cinc product" do
      config[:product_name] = "cinc"
      _(driver.send(:chef_container_name)).must_equal "cinc-latest"
    end

    it "appends the platform suffix when set" do
      config[:product_name] = "cinc"
      config[:platform]     = "linux/amd64"
      _(driver.send(:chef_container_name)).must_equal "cinc-latest-linux-amd64"
    end
  end
end
