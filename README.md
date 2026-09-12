# Enummify

Immutable, typed Ruby enums with RBS comments.
Enummify has no runtime dependencies and does not use Sorbet APIs or `T::Enum`.
Requires Ruby 3.2 or newer.

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

Each constant assignment immediately registers its member.
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

Types are declared as RBS method and constant comments in the Ruby sources.
Inherited `.deserialize` and `.values` return the concrete enum type through RBS's `instance` type.
A method annotated `#: (ExecutionStatus) -> String` can therefore require `ExecutionStatus` and reject a plain string or an unrelated enum.

Sorbet is a development dependency only; the gem does not load `sorbet-runtime` or use `T` APIs.
The gem ships `rbi/enummify.rbi` with RBS comments describing its public API.
[Tapioca imports this interface](https://github.com/Shopify/tapioca#importing-hand-written-signatures-from-gems-rbi-folder) during the application's normal gem RBI setup.
When using Sorbet, enable `--parser=prism` and `--enable-experimental-rbs-comments` to read these annotations.
The trailing constant annotations in the Ruby example support Sorbet's strict checking.

Enum instance constants do **not** provide automatic exhaustive `case` checking.
Enummify does not emulate the typechecker's special support for individual `T::Enum` members.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, testing, style and typing guidelines, and release instructions.
