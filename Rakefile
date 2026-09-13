# typed: strict
# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'

RuboCop::RakeTask.new

Rake::TestTask.new do |task|
  task.test_files = FileList['test/**/*_test.rb']
end

desc 'Build and verify the installed gem and its exported RBI'
task 'test:package' => :build do
  ruby 'test/check_package.rb'
end

desc 'Check valid and invalid enum usage with Sorbet via RBS comments'
task :typecheck do
  sh 'bundle', 'exec', 'srb', 'tc'
  ruby 'test/types/check_sorbet.rb'
end

desc 'Run tests, style checks, type checks, and package checks'
task default: %i[test rubocop typecheck test:package]
