require "rspec"
require "digest"
require "fileutils"

# Minimal stubs so we can load helpers without pulling in all of Test Kitchen
# and Docker. Only the pieces under test are real; everything else is a
# lightweight double.

module Docker
  class Error < StandardError; end
end unless defined?(Docker::Error)

module Docker
  class Image; end
end unless defined?(Docker::Image)

module Kitchen
  VERSION = "0.0.0" unless defined?(Kitchen::VERSION)

  module Driver
    class Base; end
  end unless defined?(Kitchen::Driver::Base)

  module Transport
    class Base; end
  end unless defined?(Kitchen::Transport::Base)

  module Provisioner
    class Base; end
    class ChefInfra < Base; end
  end unless defined?(Kitchen::Provisioner::Base)

  module Verifier
    class Base; end
  end unless defined?(Kitchen::Verifier::Base)
end

# Stub Chef::Log so parse_port doesn't blow up
module Chef
  module Log
    def self.fatal(msg); end
  end
end unless defined?(Chef::Log)

require_relative "../lib/kitchen/helpers"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
