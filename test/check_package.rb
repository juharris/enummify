# typed: strict
# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require_relative '../lib/enummify/version'

package_name = "enummify-#{Enummify::VERSION}"
package = File.expand_path("pkg/#{package_name}.gem")
consumer = File.expand_path('test/types/enums.rb')
typecheck = File.expand_path('test/types/check_sorbet.rb')

Dir.mktmpdir('enummify-package-') do |directory|
  # Isolate dependency discovery so the checkout cannot satisfy the consumer's require.
  environment = {
    'BUNDLE_GEMFILE' => nil,
    'GEM_HOME' => directory,
    'GEM_PATH' => directory,
    'RUBYGEMS_GEMDEPS' => nil,
    'RUBYLIB' => nil,
    'RUBYOPT' => nil
  }
  library = File.join(directory, 'gems', package_name, 'lib')
  output, status = Open3.capture2e(environment, Gem.ruby, '-S', 'gem', 'install', '--norc', '--local', '--no-document',
                                   '--install-dir', directory, package, chdir: directory)
  abort "Gem installation failed:\n#{output}" unless status.success?

  output, status = Open3.capture2e(environment, Gem.ruby, '--disable=gems', '--disable=rubyopt', '-I', library, consumer,
                                   chdir: directory)
  abort "Installed-gem usage failed:\n#{output}" unless status.success?

  interface = File.join(directory, 'gems', package_name, 'rbi', 'enummify.rbi')
  output, status = Open3.capture2e(Gem.ruby, typecheck, interface, chdir: directory)
  abort "Installed-gem type checking failed:\n#{output}" unless status.success?

  puts output
end

puts 'Installed gem: standalone usage and exported RBI passed.'
