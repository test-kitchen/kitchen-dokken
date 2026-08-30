require "bundler/gem_tasks"

require "rake/testtask"
Rake::TestTask.new(:unit) do |t|
  t.libs.push "lib"
  t.test_files = FileList["spec/**/*_spec.rb"]
  t.verbose = true
  t.warning = false
end

desc "Run all unit tests"
task test: %i{unit}

begin
  require "yard"
  YARD::Rake::YardocTask.new(:doc)

  desc "Report YARD documentation coverage"
  task :doc_stats do
    sh "yard stats --list-undoc"
  end
rescue LoadError
  puts "yard is not available. (sudo) gem install yard to generate documentation."
end

begin
  require "cookstyle/chefstyle"
  require "rubocop/rake_task"
  RuboCop::RakeTask.new(:style) do |task|
    task.options += ["--display-cop-names", "--no-color"]
  end
rescue LoadError
  puts "cookstyle/chefstyle is not available. (sudo) gem install cookstyle to do style checking."
end

task default: %i{style test}
