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

require "minitest/autorun"
require "mocha/minitest"

# Refuse to stub a method that does not exist on the object being stubbed.
#
# Without this a spec can stub `::Docker::Image.exist` (no `?`), assert
# happily against its own typo, and stay green while the real call fails for
# every user. It is the only thing standing between this suite and a
# docker-api upgrade that renames a method we depend on.
#
# Note the value: mocha's `check` silently treats an unrecognised value as
# `:allow`, so `:prohibit` or `:strict` would look configured and enforce
# nothing. `spec/mocha_configuration_spec.rb` proves this setting is live.
Mocha.configure do |c|
  c.stubbing_non_existent_method = :prevent
end
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

      # Point `Dir.home` at the shared empty home before every example, and
      # take `CI` out of the environment.
      #
      # Examples that need to write into a home directory call {#stub_home!},
      # which replaces this with one they own.
      #
      # `CI` is removed for the same reason the home directory is faked: the
      # driver forwards it into every container it creates
      # (`container_env` appends "CI=<value>" whenever it is set), so leaving
      # it ambient makes any spec that touches a container's Env assert
      # against a different payload on a runner than on a laptop. That is not
      # hypothetical -- it is what broke the create-payload snapshots.
      #
      # The forwarding behaviour is still covered, by an example that forces
      # the CI state with a stub rather than inheriting it.
      #
      # @return [void]
      def setup
        super
        Dir.stubs(:home).returns(SANDBOX_HOME)
        @original_ci = ENV.delete("CI")
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

      # An in-memory Docker daemon, installed over the real docker-api entry
      # points for the duration of this example.
      #
      # Unlike a per-call stub, this holds state: containers exist or they do
      # not, a stopped container reports itself stopped, and a `get` for
      # something that was never created raises the way the daemon does. Use
      # it for anything that exercises a sequence of operations rather than a
      # single call.
      #
      # @param images [Array<String>] image references that already exist
      # @return [Kitchen::Dokken::Spec::FakeDaemon]
      def fake_daemon(images: [])
        @fake_daemon ||= Kitchen::Dokken::Spec::FakeDaemon.new(images: images).install!
      end

      # Restore the environment, remove the scratch home directory, and
      # uninstall the fake daemon.
      #
      # The daemon replaces singleton methods on the real docker-api classes,
      # so leaving one installed would leak into every example that ran after
      # it -- in a randomly ordered suite, that is a heisenbug generator.
      #
      # @return [void]
      def teardown
        ENV["CI"] = @original_ci unless @original_ci.nil?
        @fake_daemon&.uninstall!
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
