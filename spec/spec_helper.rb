# Silence Ruby 3.4's "literal string will be frozen in the future" warnings
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

require "kitchen"

# Eager-load license-acceptance now so that the pastel/tty-* require chain
# resolves once here. Otherwise the first test that touches LicenseAcceptance
# triggers an autoload mid-test and Ruby prints a `circular require` warning
# from bundled_gems.rb across stderr, which makes the test output look like
# something failed even though everything passes.
require "license_acceptance/acceptor"
