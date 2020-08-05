lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen/driver/podman_version'

Gem::Specification.new do |spec|
  spec.name          = 'kitchen-podman'
  spec.version       = Kitchen::Driver::PODMAN_VERSION
  spec.authors       = ['Sean OMeara', 'David Marshall']
  spec.email         = ['sean@sean.io', 'dmarshall@gmail.com'],
  spec.description   = 'A Test Kitchen Driver for podman'
  spec.summary       = 'A Test Kitchen Driver that talks to podman and uses Volumes to produce sparse container images'
  spec.homepage      = 'https://github.com/dwmarshall/kitchen-podman'
  spec.license       = 'Apache-2.0'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR).grep(/LICENSE|^lib/)
  spec.require_paths = ['lib']

  spec.add_dependency 'lockfile', '~> 2.1'
  spec.add_dependency 'test-kitchen', '>= 1.15', '< 3'
end
