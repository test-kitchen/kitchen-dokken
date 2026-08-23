require_relative "../../spec_helper"

require "kitchen/driver/dokken"

# The rest of the driver suite tests one method at a time against per-call
# stubs. That answers "does this method send the right message", but it cannot
# answer "does create actually leave a running container behind", "is a second
# create safe", or "does destroy clean up after a create that half-failed" --
# because with per-call stubs there is no daemon state for the answer to live
# in.
#
# These examples run the driver against {Kitchen::Dokken::Spec::FakeDaemon},
# which holds state and enforces the daemon's own invariants, and then assert
# on what the daemon is left holding.
describe Kitchen::Driver::Dokken do
  let(:logged_output) { StringIO.new }
  let(:logger)        { Logger.new(logged_output) }
  let(:platform)      { stub(name: "almalinux-9", os_type: nil) }
  let(:suite)         { stub(name: "default") }
  let(:transport)     { stub }
  let(:provisioner)   { {} }

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

  let(:driver) { Kitchen::Driver::Dokken.new(config).finalize_config!(instance) }

  # The images a normal run finds already present, so nothing has to be
  # pulled or built for the lifecycle itself to be exercised.
  let(:daemon) do
    fake_daemon(images: ["almalinux-9", "chef/chef:latest", "dokken/kitchen-cache:latest"])
  end

  let(:state) { {} }

  # Everything that is not the container lifecycle: registry auth, image
  # pulls and builds, the sandbox on disk, and the sleeps in the retry loops.
  # Each of those has its own examples elsewhere; here they are noise.
  before do
    stub_home!
    daemon
    driver.stubs(:sleep)
    driver.stubs(:authenticate!)
    driver.stubs(:pull_platform_image)
    driver.stubs(:pull_chef_image)
    driver.stubs(:build_work_image)
    driver.stubs(:remote_docker_host?).returns(false)
    driver.stubs(:running_inside_docker?).returns(false)
    driver.stubs(:docker_connection).returns(stub("docker connection"))
    # build_work_image is stubbed out, so register what it would have built.
    daemon.add_image(driver.send(:work_image))
  end

  describe "#create" do
    it "leaves a running runner container behind" do
      driver.create(state)

      runner = daemon.containers[driver.send(:runner_container_name)]

      _(runner).wont_be_nil
      _(runner.running?).must_equal true
    end

    it "creates the chef container, which stays stopped because it is only a volume" do
      driver.create(state)

      chef = daemon.containers[driver.send(:chef_container_name)]

      _(chef).wont_be_nil
      _(chef.running?).must_equal false
    end

    it "creates the dokken network" do
      driver.create(state)

      _(daemon.networks).must_include "dokken"
    end

    it "records the running container in kitchen state, so the transport can find it" do
      driver.create(state)

      _(state[:runner_container]["Name"]).must_equal "/#{driver.send(:runner_container_name)}"
      _(state[:runner_container]["State"]["Running"]).must_equal true
    end

    it "creates the sandbox on disk" do
      driver.create(state)

      _(File.directory?(driver.send(:dokken_kitchen_sandbox))).must_equal true
    end

    # `kitchen create` on an instance that is already up must not blow up on
    # the daemon's 409, and must not end up with two containers.
    it "is safe to run twice" do
      driver.create(state)
      driver.create({})

      _(daemon.containers.keys.count { |n| n == driver.send(:runner_container_name) }).must_equal 1
      _(daemon.containers[driver.send(:runner_container_name)].running?).must_equal true
    end

    it "does not start the data container when the daemon is local" do
      driver.create(state)

      _(daemon.containers.keys).wont_include "dokken-data-default-almalinux-9"
    end

    # A container whose pid 1 exits -- a `pid_one_command` of `/bin/true`, an
    # entrypoint that returns, an image that cannot boot -- used to make
    # `kitchen create` report success and exit 0. wait_running_state breaks
    # out of its poll loop as soon as FinishedAt is set, which is exactly the
    # case for a container that has just exited, and nothing checked the
    # outcome afterwards.
    #
    # The user found out at converge, from the docker API rather than from
    # kitchen: `container dd55d579... is not running` -- a container id, no
    # instance name, and no hint that pid 1 was the problem.
    describe "when the runner container will not stay running" do
      before { daemon.exits_on_start(driver.send(:runner_container_name)) }

      it "fails the create rather than reporting success" do
        _ { driver.create(state) }.must_raise Kitchen::ActionFailed
      end

      it "names the container, so the error is about the instance not an id" do
        err = _ { driver.create(state) }.must_raise Kitchen::ActionFailed

        _(err.message).must_include driver.send(:runner_container_name)
      end

      it "points at the settings that decide whether pid 1 survives" do
        err = _ { driver.create(state) }.must_raise Kitchen::ActionFailed

        _(err.message).must_include "pid_one_command"
      end

      it "reports the exit code pid 1 left behind" do
        err = _ { driver.create(state) }.must_raise Kitchen::ActionFailed

        _(err.message).must_include "exit code 1"
      end
    end

    # A container the daemon refuses outright is a different failure from one
    # whose pid 1 exits, and it used to be reported as the second: docker-api
    # defines `Container#start` as "the same as #start!, but rescue from
    # ServerErrors", so the reason never left the gem. `kitchen create` blamed
    # `pid_one_command` and sent the user to read `docker logs`, which for a
    # container that never ran is empty.
    describe "when the daemon refuses to start the runner container" do
      let(:refusal) do
        "driver failed programming external connectivity on endpoint: " \
          "Bind for 0.0.0.0:8080 failed: port is already allocated"
      end

      before { daemon.refuses_start(driver.send(:runner_container_name), refusal) }

      it "fails the create rather than reporting success" do
        _ { driver.create(state) }.must_raise Kitchen::ActionFailed
      end

      it "reports the daemon's reason" do
        err = _ { driver.create(state) }.must_raise Kitchen::ActionFailed

        _(err.message).must_include "port is already allocated"
      end

      it "names the container, so the error is about the instance not an id" do
        err = _ { driver.create(state) }.must_raise Kitchen::ActionFailed

        _(err.message).must_include driver.send(:runner_container_name)
      end

      # The old message sent the user to a log file that cannot exist.
      it "does not blame pid 1 for a container that never ran" do
        err = _ { driver.create(state) }.must_raise Kitchen::ActionFailed

        _(err.message).wont_include "pid_one_command"
      end

      # docker-api wraps the daemon's JSON body as the exception message, so
      # reporting it verbatim leaks `{"message":"..."}` at the user.
      it "unwraps the daemon's JSON envelope" do
        err = _ { driver.create(state) }.must_raise Kitchen::ActionFailed

        _(err.message).wont_include %({"message")
      end
    end

    describe "when the data container will not stay running" do
      before do
        driver.stubs(:remote_docker_host?).returns(true)
        driver.stubs(:make_data_image)
        daemon.exits_on_start(driver.send(:data_container_name))
      end

      it "fails the create, since the transport uploads through it" do
        err = _ { driver.create(state) }.must_raise Kitchen::ActionFailed

        _(err.message).must_include driver.send(:data_container_name)
      end
    end

    # The chef container is a volume, not a service: it is created and never
    # started, so the running check must not be applied to it.
    it "does not require the chef container to be running" do
      driver.create(state)

      _(daemon.containers[driver.send(:chef_container_name)].running?).must_equal false
    end
  end

  describe "#create against a remote daemon" do
    before do
      driver.stubs(:remote_docker_host?).returns(true)
      driver.stubs(:make_data_image)
    end

    it "starts a running data container to carry the sandbox across" do
      driver.create(state)

      data = daemon.containers[driver.send(:data_container_name)]

      _(data).wont_be_nil
      _(data.running?).must_equal true
    end
  end

  describe "#destroy" do
    it "removes the runner container it created" do
      driver.create(state)

      driver.destroy(state)

      _(daemon.containers).wont_include driver.send(:runner_container_name)
    end

    it "stops the runner before deleting it" do
      driver.create(state)
      daemon.calls.clear

      driver.destroy(state)

      runner = driver.send(:runner_container_name)
      _(daemon.calls).must_include [:stop, runner]
      _(daemon.calls.index([:stop, runner])).must_be :<, daemon.calls.index([:delete, runner])
    end

    it "deletes the sandbox from disk" do
      driver.create(state)

      driver.destroy(state)

      _(File.exist?(driver.send(:dokken_kitchen_sandbox))).must_equal false
    end

    # `kitchen destroy` runs against instances that were never created, and
    # runs twice when someone is impatient. Neither may raise.
    it "is a no-op when nothing was ever created" do
      driver.destroy(state)

      _(daemon.containers).must_be_empty
    end

    it "restores the real docker-api methods when the example ends" do
      # Sanity check on the fake itself: while installed, Container.get is
      # ours. spec_helper's teardown is what puts the gem's back.
      _(::Docker::Container.method(:get).source_location.first).must_include "spec/support/fake_daemon"
    end

    it "is safe to run twice" do
      driver.create(state)
      driver.destroy(state)

      driver.destroy(state)

      _(daemon.containers).wont_include driver.send(:runner_container_name)
    end

    # The chef container is shared by every instance in the run -- it is
    # nothing but a volume holding the omnibus install, named for the chef
    # version rather than for the instance. Destroying one instance must not
    # pull it out from under the others, so it deliberately outlives destroy.
    it "leaves the shared chef container alone, since other instances use it" do
      driver.create(state)

      driver.destroy(state)

      _(daemon.containers).must_include driver.send(:chef_container_name)
    end

    it "removes the instance's own work image" do
      driver.create(state)

      driver.destroy(state)

      _(daemon.images).wont_include driver.send(:work_image)
    end

    # A create that dies partway leaves the runner container behind but never
    # reaches start. Destroy has to cope with a container that exists and is
    # not running.
    it "cleans up a runner container that was created but never started" do
      driver.send(:create_container,
        { "name" => driver.send(:runner_container_name), "Image" => "almalinux-9" })

      driver.destroy(state)

      _(daemon.containers).wont_include driver.send(:runner_container_name)
    end
  end

  describe "the daemon's own invariants" do
    # These guard the fake rather than the driver. A fake that quietly lets
    # you start a container that does not exist would make every lifecycle
    # example above meaningless.
    it "raises NotFoundError for a container that was never created" do
      _ { ::Docker::Container.get("nope", {}, nil) }.must_raise ::Docker::Error::NotFoundError
    end

    it "raises ConflictError when a name is taken" do
      ::Docker::Container.create({ "name" => "taken" }, nil)

      _ { ::Docker::Container.create({ "name" => "taken" }, nil) }
        .must_raise ::Docker::Error::ConflictError
    end

    it "creates containers stopped, so only an explicit start makes them run" do
      container = ::Docker::Container.create({ "name" => "fresh" }, nil)

      _(container.running?).must_equal false
      _(container.info["State"]["Running"]).must_equal false
    end

    it "reports a stopped container as stopped" do
      container = ::Docker::Container.create({ "name" => "toggle" }, nil)
      container.start

      container.stop

      _(container.info["State"]["Running"]).must_equal false
    end

    # wait_running_state watches FinishedAt to break out of its poll loop.
    # If the fake never stamped it, a stop would spin for all 20 tries.
    it "stamps FinishedAt on stop, which is what wait_running_state watches" do
      container = ::Docker::Container.create({ "name" => "stamped" }, nil)
      container.start
      container.stop

      _(container.info["State"]["FinishedAt"]).wont_equal Kitchen::Dokken::Spec::FakeDaemon::NEVER_FINISHED
    end

    it "forgets a container once it is deleted" do
      container = ::Docker::Container.create({ "name" => "gone" }, nil)
      container.delete

      _ { ::Docker::Container.get("gone", {}, nil) }.must_raise ::Docker::Error::NotFoundError
    end

    # Each example gets a daemon of its own. If uninstall! or the per-example
    # state ever leaked, this would see another example's containers.
    it "starts every example with an empty daemon" do
      _(daemon.containers).must_be_empty
    end
  end
end
