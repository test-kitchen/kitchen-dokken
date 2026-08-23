require_relative "spec_helper"

require "kitchen/driver/dokken"

# The suite's own guarantees.
#
# CONTRIBUTING.md promises that the unit suite is hermetic: it never reads
# your home directory and does not depend on the environment it runs in.
# Those promises are enforced in `spec/spec_helper.rb`, and this file is what
# proves the enforcement is real -- a guard nobody has watched fail is
# indistinguishable from no guard.
#
# Both guards below exist because of the same failure: a suite that passed on
# a laptop and failed on CI. The first was Docker Hub credentials on the
# runner's disk. The second was `CI=true`, which the driver forwards into
# every container it creates, so any spec asserting on a container's Env
# quietly captured a different payload depending on where it ran.
describe "unit suite hermeticity" do
  describe "the home directory" do
    it "is a scratch directory, never the real one" do
      _(Dir.home).must_equal Kitchen::Dokken::SpecHelpers::SANDBOX_HOME
    end

    it "holds no docker credentials, whatever the machine has" do
      _(File.exist?(File.join(Dir.home, ".docker", "config.json"))).must_equal false
    end
  end

  describe "the environment" do
    # Kitchen::Driver::Dokken#container_env appends "CI=<value>" to every
    # container's Env whenever CI is set. Left ambient, that makes the
    # container create payload differ between a laptop and a CI runner, which
    # is exactly what broke the payload snapshots.
    #
    # The behaviour itself is still covered, by an example that *forces* the
    # CI state rather than inheriting it -- see "forwards the CI environment
    # variable when kitchen runs in CI" in the driver spec.
    it "has no ambient CI variable to leak into container payloads" do
      _(ENV.key?("CI")).must_equal false,
        "CI is set during this example, so anything asserting on a container's " \
        "Env will behave differently here than on a developer's machine"
    end

    it "produces the same container env on a laptop and on a runner" do
      driver = Kitchen::Driver::Dokken.new(docker_info: Kitchen::Dokken::Spec.docker_info)

      _(driver.send(:container_env)).must_equal ["TEST_KITCHEN=1"]
    end
  end
end
