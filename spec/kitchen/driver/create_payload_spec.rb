require_relative "../../spec_helper"

require "kitchen/driver/dokken"

# What the driver actually asks the daemon for.
#
# Two kinds of assertion live here, deliberately:
#
# 1. Explicit examples, which say what a setting is *for* -- "privileged
#    forces UsernsMode to host", "a user-defined network gets a
#    NetworkingConfig and bridge does not". These document intent and fail
#    with a message that explains what broke.
#
# 2. A whole-payload snapshot per representative config. These say nothing
#    about intent, but they notice everything: a key that quietly stops being
#    sent, one that moves between HostConfig and the top level, a default
#    that changes shape. The explicit assertions above can only protect the
#    keys someone thought to write down.
#
# Regenerate the snapshots with `UPDATE_SNAPSHOTS=1 bundle exec rake unit`
# and read the diff -- it names the keys that moved, not the lines.
describe Kitchen::Driver::Dokken do
  Snapshot = Kitchen::Dokken::Spec::PayloadSnapshot

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

  let(:extra_config) { {} }
  let(:config)       { { docker_info: Kitchen::Dokken::Spec.docker_info }.merge(extra_config) }
  let(:driver)       { Kitchen::Driver::Dokken.new(config).finalize_config!(instance) }

  let(:daemon) { fake_daemon(images: ["almalinux-9", "chef/chef:latest"]) }

  # Deliberately touches neither `driver` nor `config`: referencing either
  # here would freeze the memoised config before an example has had a chance
  # to add to `extra_config`, and every setting-specific example below would
  # silently assert against the defaults.
  before do
    stub_home!
    # The sandbox path is a digest of the working directory, so it has to be
    # pinned for a snapshot to be stable across checkouts.
    FileUtils.stubs(:pwd).returns("/some/project")
    daemon
  end

  # Run the real code path and hand back exactly what the daemon was asked
  # for -- not a hash the spec reconstructed from the same source.
  #
  # @return [Hash] the create request
  def runner_payload
    driver.stubs(:sleep)
    driver.stubs(:remote_docker_host?).returns(false)
    driver.stubs(:running_inside_docker?).returns(false)
    driver.stubs(:docker_connection).returns(stub("docker connection"))
    daemon.add_image(driver.send(:work_image))

    driver.send(:start_runner_container, {})
    daemon.containers[driver.send(:runner_container_name)].create_options
  end

  # The configurations worth snapshotting: each one takes a different branch
  # through start_runner_container.
  SNAPSHOT_CASES = {
    "runner-default"    => {},
    "runner-host-net"   => { network_mode: "host" },
    "runner-privileged" => { privileged: true, cap_add: %w{SYS_ADMIN}, security_opt: %w{seccomp=unconfined} },
    "runner-storage"    => {
      tmpfs: { "/tmp" => "rw,noexec,size=64m" },
      volumes: ["/var/log/dokken"],
      binds: ["/host/path:/container/path:ro"],
    },
    "runner-networking" => {
      dns: ["8.8.8.8"],
      dns_search: ["example.com"],
      hostname_aliases: %w{alias-one alias-two},
      ports: ["8080:80", "53/udp"],
    },
    # A pinned :platform is deliberately absent: that path bypasses
    # Docker::Container.create and POSTs to the connection directly, so the
    # payload never reaches the daemon here. #create_container_for_platform
    # has its own examples in dokken_spec.rb.
    "runner-registry"   => { image_prefix: "registry.example.com", memory_limit: 536_870_912 },
  }.freeze

  SNAPSHOT_CASES.each do |name, settings|
    describe "the #{name} create payload" do
      let(:extra_config) { settings }

      it "matches its snapshot" do
        expected, actual = Snapshot.compare(name, runner_payload, home: tmphome)

        _(actual).must_equal expected, Snapshot.message(expected, actual, name)
      end
    end
  end

  describe "what the payload means" do
    it "sends the work image, not the platform image, as the runner's image" do
      _(runner_payload["Image"]).must_equal driver.send(:short_image_path, driver.send(:work_image))
    end

    it "word-splits pid_one_command, since docker takes Cmd as an array" do
      _(runner_payload["Cmd"]).must_equal ["sh", "-c", "trap exit 0 SIGTERM; while :; do sleep 1; done"]
    end

    describe "networking" do
      it "attaches a NetworkingConfig on a user-defined network" do
        _(runner_payload["NetworkingConfig"]["EndpointsConfig"]).must_include "dokken"
      end

      it "lists the hostname and its aliases as network aliases" do
        extra_config[:hostname_aliases] = %w{alias-one}

        aliases = runner_payload["NetworkingConfig"]["EndpointsConfig"]["dokken"]["Aliases"]

        _(aliases).must_equal %w{dokken alias-one}
      end

      # host and bridge are docker's own networks; asking to attach an
      # endpoint configuration to them is an error, not a no-op.
      it "omits NetworkingConfig entirely on the host network" do
        extra_config[:network_mode] = "host"

        _(runner_payload).wont_include "NetworkingConfig"
      end

      it "omits NetworkingConfig entirely on the default bridge" do
        extra_config[:network_mode] = "bridge"

        _(runner_payload).wont_include "NetworkingConfig"
      end

      it "carries dns settings into the network endpoint" do
        extra_config[:dns] = ["1.1.1.1"]
        extra_config[:dns_search] = ["example.com"]

        dns = runner_payload["NetworkingConfig"]["EndpointsConfig"]["dokken"]["DNSConfig"]

        _(dns["Nameservers"]).must_equal ["1.1.1.1"]
        _(dns["Search"]).must_equal ["example.com"]
      end
    end

    describe "privileged mode" do
      # Docker refuses to run a privileged container inside a user namespace,
      # so the driver forces UsernsMode regardless of what was configured.
      it "forces UsernsMode to host, because the two are incompatible" do
        extra_config[:privileged] = true
        extra_config[:user_ns_mode] = "somethingelse"

        _(runner_payload["HostConfig"]["UsernsMode"]).must_equal "host"
      end

      it "leaves UsernsMode alone when not privileged" do
        _(runner_payload["HostConfig"]).wont_include "UsernsMode"
      end

      it "sets UsernsMode from userns_host without privileged" do
        extra_config[:userns_host] = true

        _(runner_payload["HostConfig"]["UsernsMode"]).must_equal "host"
      end
    end

    describe "the entrypoint" do
      it "is omitted when not configured, so the image's own is used" do
        _(runner_payload).wont_include "Entrypoint"
      end

      it "is sent when configured" do
        extra_config[:entrypoint] = ["/bin/sh", "-c", "sleep infinity"]

        _(runner_payload["Entrypoint"]).must_equal ["/bin/sh", "-c", "sleep infinity"]
      end
    end

    describe "cgroups" do
      it "omits CgroupnsMode by default" do
        _(runner_payload["HostConfig"]).wont_include "CgroupnsMode"
      end

      it "sets CgroupnsMode to host when asked" do
        extra_config[:cgroupns_host] = true

        _(runner_payload["HostConfig"]["CgroupnsMode"]).must_equal "host"
      end
    end
  end
end
