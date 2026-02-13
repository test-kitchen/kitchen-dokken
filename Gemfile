source "https://rubygems.org"

gemspec

gem "chef-test-kitchen-enterprise", git: "https://github.com/chef/chef-test-kitchen-enterprise", branch: "main", glob: "chef-test-kitchen-enterprise.gemspec"
# Override transitive dependency on test-kitchen with chef-test-kitchen-enterprise
# The git repo now includes a test-kitchen.gemspec alias to satisfy transitive dependencies
gem "test-kitchen", git: "https://github.com/chef/chef-test-kitchen-enterprise", branch: "main", glob: "test-kitchen.gemspec"

group :test do
  gem "syslog" # this is a workaround for ruby 3.4 support in berkshelf 8.0.22 and can be removed when a new version of berkshelf is released
  gem "csv" # this is a workaround for ruby 3.4 support in inspec-core 6.8.24 and can be removed when a new version of inspec-core is released
  gem "berkshelf"
  gem "kitchen-inspec"
  gem "rake", ">= 11.0"
end

group :development do
  gem "pry"
end

group :cookstyle do
  gem "cookstyle", "~> 8.4"
end
