# Enummify

Immutable, typed Ruby enums with RBS comments.
Enummify has no runtime dependencies and does not use Sorbet APIs or `T::Enum`.
Requires Ruby 4.0.6 or newer.

## Usage

Add `gem 'enummify'` to the application's Gemfile, then run `bundle install`.

```ruby
# typed: strict

require 'enummify'

class ExecutionStatus < Enummify::Enum
  Pending = new #: ExecutionStatus
  RUNNING = new #: ExecutionStatus
  Succeeded = new #: ExecutionStatus
end

ExecutionStatus::RUNNING == ExecutionStatus.deserialize('RUNNING')
ExecutionStatus::Pending.serialize # => 'Pending'
ExecutionStatus::RUNNING.serialize # => 'RUNNING'
ExecutionStatus.values # => [ExecutionStatus::Pending, ExecutionStatus::RUNNING, ExecutionStatus::Succeeded]
ExecutionStatus.try_deserialize('unknown') # => nil
```

Each member is an instance of its own enum class.
Members from different enum classes are distinct even when they serialize to the same string.
Members and their serialized strings are frozen.
`.values` returns a frozen snapshot in declaration order; earlier snapshots remain unchanged when new members are declared.
`dup`, `clone`, and Marshal round trips preserve the canonical member's identity.

Declare members directly as constants in the enum class body.
By default, serialization uses the constant's exact name, preserving capitalization.
Pass a string, such as `Succeeded = new('succeeded') #: ExecutionStatus`, to choose a custom serialized value.
Serialized values must be unique within the enum.
Every constant defined directly on the class must be a member of that enum.
Invalid members, duplicate names, duplicate serialized values, and aliases raise immediately.
Concrete enum classes cannot be subclassed.
The `new` constructor is private.

Each constant assignment immediately registers its member through Ruby's `const_added` callback.
Lookup and enumeration only read the registry.
The class can be reopened to add members and methods, including after a lookup.
Finish member declarations during application loading before concurrent use; concurrent mutation is unsupported.

An empty enum returns `[]` from `.values` and `nil` from `.try_deserialize`.
`.deserialize` raises `ArgumentError` for an unknown string, while `.try_deserialize` returns `nil`.
Both reject non-strings with `TypeError` rather than coercing input.
Serialize at JSON, configuration, and persistence boundaries:

```ruby
# typed: strict

require 'json'

json = JSON.generate(status: ExecutionStatus::RUNNING.serialize)
status = ExecutionStatus.deserialize(JSON.parse(json).fetch('status'))
```

## Typing

Types are declared as RBS method and constant comments in the Ruby sources and checked in CI with Sorbet's static checker.
Inherited `.deserialize` and `.values` return the concrete enum type through RBS's `instance` type.
A method annotated `#: (ExecutionStatus) -> String` can therefore require `ExecutionStatus` and reject a plain string or an unrelated enum.

Sorbet is a development dependency only; the gem does not load `sorbet-runtime` or use `T` APIs.
When using Sorbet, enable `--parser=prism` and `--enable-experimental-rbs-comments`, and include the gem's Ruby sources in the checker's inputs.
The trailing constant annotations in the Ruby example support Sorbet's strict checking.

Enum instance constants do **not** provide automatic exhaustive `case` checking.
Enummify does not emulate the typechecker's special support for individual `T::Enum` members.

## Setup

Use Ruby 4.0.6.
The `.ruby-version` file pins local development and all CI jobs to Ruby 4.0.6.

```shell
bundle install
```

## Testing

```shell
bundle exec rake test
```

## Style and typing

```shell
bundle exec rubocop --cache true
bundle exec rake typecheck
```

Type checks cover the library and runtime tests, along with valid usage and intentional errors such as passing another enum, a raw string, or a possibly missing member.
They also reject unknown member constants.
The Sorbet check verifies valid fixtures and each marked invalid call in `test/types/`.

Apply style fixes:

```shell
bundle exec rubocop --autocorrect --cache true
```

Run all checks:

```shell
bundle exec rake
```

## Building and publishing

```shell
bundle exec rake build
```

GitHub Actions tests and builds the gem on Ruby 4.0.6, with style and type checks sharing the Ubuntu job's Ruby setup.
After checks pass on `main`, the workflow publishes versions that are not already on RubyGems using trusted publishing.
Before the first release, register a [pending trusted publisher](https://rubygems.org/profile/oidc/pending_trusted_publishers) for gem `enummify`, repository `juharris/enummify`, and workflow `ruby_build_test.yml`.
Leave the environment field empty, matching this workflow.
Bump `Enummify::VERSION` in `lib/enummify/version.rb` to release a new version.
