require_relative "../spec_helper"

require "kitchen/driver/dokken"
require "kitchen/provisioner/dokken"
require "kitchen/transport/dokken"

# What `kitchen diagnose` reports about the three dokken plugins.
#
# This is the first thing a bug report carries, so it is worth a test of its
# own: every plugin used to report `Kitchen::VERSION` -- test-kitchen's
# version -- as its own, which tells a maintainer nothing about the plugin the
# report is actually about, and the driver reported nothing at all.
describe "plugin metadata" do
  PLUGINS = {
    "driver" => Kitchen::Driver::Dokken,
    "provisioner" => Kitchen::Provisioner::Dokken,
    "transport" => Kitchen::Transport::Dokken,
  }.freeze

  PLUGINS.each do |kind, plugin|
    describe "the #{kind}" do
      it "reports kitchen-dokken's own version" do
        _(plugin.diagnose[:version]).must_equal Kitchen::Driver::DOKKEN_VERSION
      end

      # The specific wrong answer this replaced. Worth naming, because the two
      # constants are one word apart and the mistake reads as correct.
      it "does not report test-kitchen's version as its own" do
        _(plugin.diagnose[:version]).wont_equal Kitchen::VERSION
      end

      it "declares plugin api version 2" do
        _(plugin.diagnose[:api_version]).must_equal 2
      end

      it "names itself" do
        _(plugin.diagnose[:class]).must_equal plugin.name
      end
    end
  end
end
