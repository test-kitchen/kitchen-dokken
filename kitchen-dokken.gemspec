lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "kitchen/driver/dokken_version"

Gem::Specification.new do |spec|
  spec.name          = "kitchen-dokken"
  spec.version       = Kitchen::Driver::DOKKEN_VERSION
  spec.authors       = ["Sean OMeara"]
  spec.email         = ["sean@sean.io"]
  spec.description   = "A Test Kitchen Driver for Docker & Chef Infra optimized for rapid testing using Chef Infra docker images"
  spec.summary       = "A Test Kitchen Driver for Docker & Chef Infra optimized for rapid testing using Chef Infra docker images"
  spec.homepage      = "https://github.com/someara/kitchen-dokken"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR).grep(/LICENSE|^lib/)
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.5"

  spec.add_dependency "docker-api", ">= 1.33", "< 3"
  spec.add_dependency "lockfile", "~> 2.1"
  spec.add_dependency "test-kitchen", ">= 1.15", "< 4"
end
