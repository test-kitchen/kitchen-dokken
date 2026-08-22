source "https://rubygems.org"

gemspec

group :test do
  gem "syslog" # this is a workaround for ruby 3.4 support in berkshelf 8.0.22 and can be removed when a new version of berkshelf is released
  gem "csv" # this is a workaround for ruby 3.4 support in inspec-core 6.8.24 and can be removed when a new version of inspec-core is released
  gem "berkshelf"
  gem "kitchen-inspec"
  gem "minitest"
  gem "mocha"
  gem "rake", ">= 11.0"
  gem "simplecov", require: false # opt-in via COVERAGE=1
end

group :development do
  gem "pry"
  gem "yard" # `rake doc` -- documentation is not gated in CI
end

group :cookstyle do
  gem "cookstyle", "~> 8.4"
end
