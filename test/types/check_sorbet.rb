# typed: strict
# frozen_string_literal: true

require 'open3'

binary = File.join(Gem::Specification.find_by_name('sorbet-static').full_gem_path, 'libexec', 'sorbet')
command = [binary, '--no-error-count', '--no-error-sections', '--color=never']

unless ARGV.empty?
  # Consumer checks must not resolve types from the checkout's implementation.
  command.concat(%w[--no-config --parser=prism --enable-experimental-rbs-comments])
  command.concat(ARGV)
  command << File.expand_path('enums.rb', __dir__)
end

output, status = Open3.capture2e(*command)
abort output unless status.success?

fixture = File.expand_path('invalid.rb', __dir__)
expected = File.readlines(fixture).each_with_index.filter_map do |line, index|
  match = line.match(/^\s*# expect-type-error: (\d+)/)
  [fixture, index + 2, match[1]] if match
end

output, status = Open3.capture2e(*command, fixture)
actual = output.scan(%r{^(.+\.rb):(\d+): .*https://srb\.help/(\d+)})
actual.map! { |file, line, code| [file, line.to_i, code] }

unless status.exitstatus == 100 && actual.sort == expected.sort
  warn output
  abort "Unexpected Sorbet diagnostics (exit #{status.exitstatus}).\nExpected: #{expected.inspect}\nActual: #{actual.inspect}"
end

puts "Sorbet: valid usage passed; all #{expected.length} invalid calls rejected."
