# typed: strict
# frozen_string_literal: true

require_relative 'lib/enummify/version'

Gem::Specification.new do |spec|
  spec.authors = ['Justin D. Harris']
  spec.description = 'Immutable, typed Ruby enums with RBS comments and no runtime dependencies.'
  spec.files = Dir['lib/**/*.rb', 'rbi/**/*.rbi']
  spec.homepage = 'https://github.com/juharris/enummify'
  spec.license = 'MIT'
  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/juharris/enummify/issues',
    'source_code_uri' => 'https://github.com/juharris/enummify'
  }
  spec.name = 'enummify'
  spec.required_ruby_version = '>= 3.2'
  spec.summary = 'Typed Ruby enums using RBS.'
  spec.version = Enummify::VERSION

  spec.add_development_dependency 'rake', '~> 13.2'
  spec.add_development_dependency 'sorbet', '~> 0.6.13426'
  spec.add_development_dependency 'test-unit', '~> 3.6.8'
end
