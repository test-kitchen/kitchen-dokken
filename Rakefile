# release tooling
require "bundler/gem_tasks"

begin
  require "chefstyle"
  require "rubocop/rake_task"
  RuboCop::RakeTask.new(:style) do |task|
    task.options += ["--display-cop-names", "--no-color"]
  end
rescue LoadError
  puts "chefstyle is not available. (sudo) gem install chefstyle to do style checking."
end
task default: %i{style}
