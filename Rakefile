# typed: strict
# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'

RuboCop::RakeTask.new

Rake::TestTask.new do |task|
  task.test_files = FileList['test/**/*_test.rb']
end

desc 'Check valid and invalid enum usage with Sorbet via RBS comments'
task :typecheck do
  ruby 'test/types/check_sorbet.rb'
end

desc 'Run tests, style checks, and type checks'
task default: %i[test rubocop typecheck]
