require "rake/testtask"
require "rubocop/rake_task"

task default: [:rubocop, :test]

Rake::TestTask.new do |t|
  t.warning = false
end

RuboCop::RakeTask.new
