source "https://rubygems.org"

# Specify your gem's dependencies in kitchen-dokken.gemspec
gemspec

group :test do
  gem "berkshelf"
  gem "kitchen-inspec"
  gem "rake", ">= 11.0"
end

group :development do
  gem "pry"
  gem "pry-byebug"
end

group :linting do
  gem "cookstyle", "7.32.8"
end
