source "https://rubygems.org"

# Specify your gem's dependencies in kitchen-dokken.gemspec
gemspec

gem "berkshelf"

group :test do
  gem "berkshelf"
  gem "kitchen-inspec"
  gem "rake", ">= 11.0"
end

group :development do
  gem "pry"
  gem "pry-byebug"
end

group :chefstyle do
  gem "chefstyle", "2.2.3"
end
