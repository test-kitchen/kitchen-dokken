require_relative "../spec_helper"

require "kitchen/driver/dokken"
require "kitchen/transport/dokken"
require "kitchen/provisioner/dokken"

# kitchen-dokken ships three plugins that have to agree with each other, and
# every other spec in this suite tests exactly one of them with the other two
# stubbed. That leaves the handoffs -- the things one plugin writes and
# another reads -- asserted from both sides against nobody.
#
# The sharpest example is the shape of kitchen state. The driver stores raw
# docker inspect payloads, which are String-keyed JSON:
#
#     state[:data_container] = data_container.json   # => {"NetworkSettings" => ...}
#
# and the transport reads them with Symbol keys:
#
#     options[:data_container][:NetworkSettings][:Ports][:"22/tcp"]
#
# Those only line up because Test Kitchen writes state to `.kitchen/*.yml`
# between the two calls and `Kitchen::StateFile#read` deep-symbolizes what it
# reads back. Nothing in either plugin says so, no unit test covers it, and
# a well-meaning change on either side -- symbolizing in the driver, or
# reading String keys in the transport -- breaks a real `kitchen verify`
# while the whole unit suite stays green.
#
# These examples put the real StateFile in the middle and assert the handoff
# end to end.
describe "the driver/transport/provisioner handoff" do
  let(:logged_output) { StringIO.new }
  let(:logger)        { Logger.new(logged_output) }
  let(:platform)      { stub(name: "almalinux-9", os_type: nil) }
  let(:suite)         { stub(name: "default") }
  let(:provisioner)   { {} }

  let(:instance) do
    stub(
      name: "default-almalinux-9",
      logger: logger,
      suite: suite,
      platform: platform,
      transport: stub,
      provisioner: provisioner,
      to_str: "default-almalinux-9"
    )
  end

  let(:driver_config) { { docker_info: Kitchen::Dokken::Spec.docker_info } }
  let(:driver)        { Kitchen::Driver::Dokken.new(driver_config).finalize_config!(instance) }

  let(:daemon) do
    fake_daemon(images: ["almalinux-9", "chef/chef:latest", "dokken/kitchen-cache:latest"])
  end

  before do
    stub_home!
    daemon
    driver.stubs(:sleep)
    driver.stubs(:authenticate!)
    driver.stubs(:pull_platform_image)
    driver.stubs(:pull_chef_image)
    driver.stubs(:build_work_image)
    driver.stubs(:make_data_image)
    driver.stubs(:docker_connection).returns(stub("docker connection"))
    daemon.add_image(driver.send(:work_image))
  end

  # Run a real `kitchen create`, then push the resulting state through a real
  # StateFile exactly the way Test Kitchen does between actions.
  #
  # @return [Hash] the state as the transport will actually receive it
  def state_after_create
    state = {}
    driver.create(state)

    state_file = Kitchen::StateFile.new(tmphome, "default-almalinux-9")
    state_file.write(state)
    state_file.read
  end

  describe "kitchen state as the transport receives it" do
    before do
      driver.stubs(:remote_docker_host?).returns(true)
      driver.stubs(:running_inside_docker?).returns(false)
    end

    it "arrives with symbol keys all the way down, not the driver's strings" do
      state = state_after_create

      _(state[:data_container].keys).must_include :NetworkSettings
      _(state[:data_container][:NetworkSettings]).must_be_kind_of Hash
    end

    # This is the assertion the transport's ssh_port_binding depends on, and
    # the reason the driver must NOT symbolize before storing: it would be
    # symbolizing something StateFile is about to symbolize again, and the
    # `"22/tcp"` key in particular has to survive as :"22/tcp".
    it "keeps the data container's published ssh port reachable by the transport" do
      state = state_after_create

      binding = state[:data_container][:NetworkSettings][:Ports][:"22/tcp"]

      _(binding).wont_be_nil
      _(binding.first).must_include :HostPort
    end

    it "carries the runner container name the transport execs against" do
      state = state_after_create

      _(state[:instance_name]).must_equal driver.send(:instance_name)
    end

    it "carries the image prefix the transport uses to name the work image" do
      driver_config[:image_prefix] = "myregistry.example.com"
      state = state_after_create

      _(state[:image_prefix]).must_equal "myregistry.example.com"
    end
  end

  describe "the transport consuming that state" do
    let(:transport_config) do
      {
        docker_info: Kitchen::Dokken::Spec.docker_info,
        docker_host_url: "unix:///var/run/docker.sock",
      }
    end

    before do
      driver.stubs(:remote_docker_host?).returns(true)
      driver.stubs(:running_inside_docker?).returns(false)
    end

    # The whole point: build the connection from state the driver really
    # produced, rather than from a hash a spec author invented to match the
    # transport's expectations.
    def connection_for(state)
      transport = Kitchen::Transport::Dokken.new(transport_config).finalize_config!(instance)
      transport.connection(state)
    end

    it "finds the data container's ssh endpoint in the driver's own state" do
      connection = connection_for(state_after_create)

      binding = connection.send(:ssh_port_binding)

      _(binding[:HostPort]).wont_be_nil
    end

    it "finds the data container's address on the dokken network" do
      connection = connection_for(state_after_create)

      _(connection.send(:data_container_ip)).wont_be_empty
    end

    it "execs against the runner container the driver actually started" do
      connection = connection_for(state_after_create)

      _(connection.send(:instance_name)).must_equal driver.send(:instance_name)
    end

    # data_container_ip raises rather than returning "" when the daemon
    # reports no address anywhere, because an empty address silently produced
    # `root@:/opt/kitchen` and an unresolvable rsync target.
    it "raises a transport failure rather than uploading to an empty address" do
      state = state_after_create
      state[:data_container][:NetworkSettings][:IPAddress] = ""
      state[:data_container][:NetworkSettings][:Networks] = {}

      connection = connection_for(state)

      _ { connection.send(:data_container_ip) }.must_raise Kitchen::Transport::TransportFailed
    end
  end

  describe "the provisioner and transport agreeing on the sandbox" do
    let(:provisioner_instance) do
      stub(
        name: "default-almalinux-9",
        logger: logger,
        suite: suite,
        platform: platform,
        driver: { chef_version: "latest" },
        transport: stub,
        provisioner: { root_path: "/opt/kitchen" },
        to_str: "default-almalinux-9"
      )
    end

    let(:kitchen_provisioner) do
      Kitchen::Provisioner::Dokken.new(
        kitchen_root: "/rooty",
        test_base_path: "/basist",
        docker_info: Kitchen::Dokken::Spec.docker_info
      ).finalize_config!(provisioner_instance)
    end

    # The provisioner writes the converge payload into the kitchen sandbox
    # and the transport uploads from it. They derive the path independently,
    # through the same helper -- if either stopped agreeing, a converge would
    # upload an empty directory and chef would run against nothing.
    it "derives the same sandbox path from both plugins" do
      _(kitchen_provisioner.send(:dokken_kitchen_sandbox))
        .must_equal driver.send(:dokken_kitchen_sandbox)
    end

    it "puts the sandbox somewhere the driver has actually created" do
      driver.stubs(:remote_docker_host?).returns(false)
      driver.stubs(:running_inside_docker?).returns(false)
      driver.create({})

      _(File.directory?(kitchen_provisioner.send(:dokken_kitchen_sandbox))).must_equal true
    end

    # The driver binds the sandbox into the runner container at the
    # provisioner's root_path. If those two disagreed, chef would start and
    # find no dna.json.
    it "binds the sandbox to the root path the provisioner will converge from" do
      driver.stubs(:remote_docker_host?).returns(false)
      driver.stubs(:running_inside_docker?).returns(false)
      driver.create({})

      runner = daemon.containers[driver.send(:runner_container_name)]
      binds  = runner.create_options["HostConfig"]["Binds"]

      _(binds.join(" ")).must_include kitchen_provisioner.send(:resolved_root_path)
    end
  end
end
