require "rake/testtask"
require "rubocop/rake_task"

task default: [:test, :rubocop]

Rake::TestTask.new do |t|
  t.warning = false
end

RuboCop::RakeTask.new
