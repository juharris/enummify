# Enummify

[![Gem Version](https://badge.fury.io/rb/enummify.svg?icon=si%3Arubygems&icon_color=%23ec3c3c)](https://rubygems.org/gems/enummify)

Create immutable, [RBS comment](https://sorbet.org/docs/rbs-support)-friendly, typed Ruby enums without a direct dependency on Sorbet.
Enummify has no runtime dependencies and does not use Sorbet's `T::Enum`.
Enummify provides minimal safeguards and expects enums to be used as documented in order to keep the library simple and efficient.

## Usage

```Ruby
# typed: strict

require 'enummify'

class Status < Enummify::Enum
  PENDING = new #: Status
  RUNNING = new #: Status
  SUCCEEDED = new("Done") #: Status
end

Status::RUNNING == Status.deserialize('RUNNING') # => true
Status::PENDING.serialize # => 'PENDING'
Status::RUNNING.serialize # => 'RUNNING'
Status.values # => [Status::PENDING, Status::RUNNING, Status::SUCCEEDED]
Status.try_deserialize('unknown') # => nil
Status.deserialize('something else') # => raises ArgumentError
```

Each member is an instance of its own enum class.
Members and their serialized strings are frozen.

Declare members directly as constants in the enum class body.
By default, serialization uses the constant's exact name, preserving capitalization.
Pass a string, such as `SUCCEEDED = new('Succeeded') #: Status`, to choose a custom serialized value.
Serialized values must be unique within the enum.
Every constant defined directly on the class must be a member of that enum.
Duplicate serialized values raise immediately.

Each constant assignment immediately registers its member.

An empty enum returns `[]` from `.values` and `nil` from `.try_deserialize`.
`.deserialize` raises `ArgumentError` for an unknown string, while `.try_deserialize` returns `nil`.
Serialize at JSON, configuration, and persistence boundaries:

```ruby
# typed: strict

require 'json'

json = JSON.generate(status: Status::RUNNING.serialize) # => '{"status":"RUNNING"}'
Status.deserialize(JSON.parse(json).fetch('status')) # => Status::RUNNING
```

## Typing

Types are declared as RBS method and constant comments in the Ruby sources.
Sorbet is a development dependency only; the runtime does not load `sorbet-runtime` or use `T` APIs.
The gem ships standard Sorbet signatures in `rbi/enummify.rbi` describing its public API.
[Tapioca imports this interface](https://github.com/Shopify/tapioca#importing-hand-written-signatures-from-gems-rbi-folder) during the application's normal gem RBI setup.
To use RBS comments in application code, enable Sorbet's `--parser=prism` and `--enable-experimental-rbs-comments` flags.
The trailing constant annotations in the Ruby example support Sorbet's strict checking.

Enum instance constants do **not** provide automatic exhaustive `case` checking.
Enummify does not emulate the typechecker's special support for individual `T::Enum` members.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, testing, style and typing guidelines, and release instructions.
