source "https://rubygems.org"

gemspec

gem "chef-test-kitchen-enterprise", git: "https://github.com/chef/chef-test-kitchen-enterprise", branch: "main", glob: "chef-test-kitchen-enterprise.gemspec"
# Override transitive dependency on test-kitchen with chef-test-kitchen-enterprise
# The git repo now includes a test-kitchen.gemspec alias to satisfy transitive dependencies
gem "test-kitchen", git: "https://github.com/chef/chef-test-kitchen-enterprise", branch: "main", glob: "test-kitchen.gemspec"
# Check if Artifactory is accessible, otherwise use GitHub
artifactory_url = "https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local"
artifactory_available = begin
                          require "net/http"
                          require "uri"
                          uri = URI.parse(artifactory_url)
                          http = Net::HTTP.new(uri.host, uri.port)
                          http.use_ssl = true
                          http.open_timeout = 3
                          http.read_timeout = 3
                          response = http.head(uri.path)
                          response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
                        rescue StandardError
                          false
                        end

if artifactory_available
  source artifactory_url do
    gem "kitchen-chef-enterprise"
  end
else
  gem "kitchen-chef-enterprise", git: "https://github.com/chef/kitchen-chef-enterprise", branch: "main"
end

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
  gem "cookstyle", ">= 8.4"
end
