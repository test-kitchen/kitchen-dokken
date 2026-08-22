# Unit-test bootstrap for kitchen-dokken.
#
# Everything in spec/ is hermetic: no Docker daemon, no network, no reads of
# the real home directory, no writes outside a temporary directory, and no
# sleeping. Anything that would reach out to the world is stubbed at the seam,
# and `spec/support` holds the shared doubles that make those seams cheap to
# fake.

# Silence Ruby 3.4+'s "literal string will be frozen in the future" warnings
# emitted by upstream gems (mixlib-shellout, test-kitchen) so that test
# output isn't drowned by issues we can't fix here. Real warnings from our
# own code still pass through.
module Warning
  def self.warn(msg, category: nil)
    return if msg.include?("literal string will be frozen")

    super
  end
end

# Opt-in coverage: `COVERAGE=1 bundle exec rake unit`, or `rake coverage`.
# Deliberately not enforced -- it is a tool for finding gaps, not a gate.
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/spec/"
    enable_coverage :branch
  end
end

require "minitest/autorun"
require "mocha/minitest"
require "tmpdir"
require "fileutils"
require "json"
require "stringio"

require "kitchen"
require "docker"

# Eager-load license-acceptance now so that the pastel/tty-* require chain
# resolves once here. Otherwise the first test that touches LicenseAcceptance
# triggers an autoload mid-test and Ruby prints a `circular require` warning
# from bundled_gems.rb across stderr, which makes the test output look like
# something failed even though everything passes.
require "license_acceptance/acceptor"

Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |f| require f }

module Kitchen
  module Dokken
    # Behaviour shared by every spec in this suite.
    #
    # Including this into a `describe` block gives the example a scratch
    # `$HOME` (so sandbox helpers write somewhere disposable) and asserts that
    # no example leaks a real Docker connection.
    module SpecHelpers
      # An empty home directory shared by the whole suite.
      #
      # Every example is pointed here so that nothing can read the real
      # ~/.docker/config.json, ~/.ssh or ~/.dokken. A spec that passes only
      # because the machine running it happens to have no Docker credentials
      # is not a spec -- and CI runners do have them.
      SANDBOX_HOME = Dir.mktmpdir("dokken-spec-home")
      Minitest.after_run { FileUtils.remove_entry(SANDBOX_HOME) if File.directory?(SANDBOX_HOME) }

      # Point `Dir.home` at the shared empty home before every example.
      #
      # Examples that need to write into a home directory call {#stub_home!},
      # which replaces this with one they own.
      #
      # @return [void]
      def setup
        super
        Dir.stubs(:home).returns(SANDBOX_HOME)
      end

      # A disposable directory that lives for the duration of one example.
      #
      # @return [String] absolute path to the temporary directory
      def tmphome
        @tmphome ||= Dir.mktmpdir("dokken-spec")
      end

      # Point `Dir.home` at {#tmphome} so sandbox helpers stay off the real
      # home directory.
      #
      # @return [String] the temporary home directory
      def stub_home!
        Dir.stubs(:home).returns(tmphome)
        tmphome
      end

      # Remove the scratch home directory, if one was created.
      #
      # @return [void]
      def teardown
        FileUtils.remove_entry(@tmphome) if @tmphome && File.directory?(@tmphome)
        super
      end
    end
  end
end

module Minitest
  # Mixed into every spec class so {Kitchen::Dokken::SpecHelpers} is always
  # available without per-file boilerplate.
  class Spec
    include Kitchen::Dokken::SpecHelpers
  end
end
