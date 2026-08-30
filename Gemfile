source "https://rubygems.org"

gemspec

group :test do
  gem "syslog" # this is a workaround for ruby 3.4 support in berkshelf 8.0.22 and can be removed when a new version of berkshelf is released
  gem "berkshelf"
  gem "kitchen-inspec"
  # Pin to the last Apache-2.0 line of inspec-core. From 6.6.0 onwards the gem
  # ships under LicenseRef-Chef-EULA and refuses to run without a Chef license
  # entitlement, which would make `kitchen verify` impossible in CI and on
  # forks. kitchen-inspec allows anything up to 8.0, so without this pin a
  # fresh resolve silently lands on the licensed line. Cinc Auditor is built
  # from this same Apache-2.0 source; there is no cinc-auditor gem to depend
  # on instead.
  gem "inspec-core", "< 6"
  gem "minitest"
  gem "mocha"
  gem "rake", ">= 11.0"
end

group :development do
  gem "yard" # `rake doc` -- documentation is not gated in CI
end

group :cookstyle do
  gem "cookstyle", "~> 9.0"
end
