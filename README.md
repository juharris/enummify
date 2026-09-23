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
The member count is therefore fixed once the class body finishes.
`Enum.values`, `EnumSet.all`, complement, and `EnumHash`'s capacity all read from that registry, so a member added dynamically afterwards is invisible to them.

An empty enum returns `[]` from `.values` and `nil` from `.try_deserialize`.
`.deserialize` raises `ArgumentError` for an unknown string, while `.try_deserialize` returns `nil`.
Serialize at JSON, configuration, and persistence boundaries:

```ruby
# typed: strict

require 'json'

json = JSON.generate(status: Status::RUNNING.serialize) # => '{"status":"RUNNING"}'
Status.deserialize(JSON.parse(json).fetch('status')) # => Status::RUNNING
```

## Sets

`Enummify::EnumSet` is an immutable set of members of a single enum, stored as one `Integer` bitmask.
Each member occupies the bit at its declaration index, so union, intersection,
difference and subset tests are single `Integer` operations rather than hash walks.

Every constant in an enum class body must be a member, so a named grouping lives outside the class:

```ruby
# typed: strict

IN_FLIGHT = Status.set(Status::PENDING, Status::RUNNING)

IN_FLIGHT.include?(Status::RUNNING) # => true
IN_FLIGHT | Status.set(Status::SUCCEEDED) # => a new set of all three
~IN_FLIGHT # => the set of every other member
IN_FLIGHT.to_a # => [Status::PENDING, Status::RUNNING]

case status
when IN_FLIGHT then 'still working'
else 'finished'
end
```

`Status.set` takes the member type from its arguments, so it needs at least one member.
Build the other sets with `Enummify::EnumSet.none(Status)`, `Enummify::EnumSet.all(Status)`, or
`Enummify::EnumSet.from(Status, members)` for a collection you already have.
`Enummify::EnumSet.of(Status, ...)` is the same as `Status.set` with the enum written out.

Sets are immutable, so `add` and `delete` return a new set rather than changing the receiver.
`|`, `&`, `-`, `^` and `~` are aliased as `union`, `intersection`, `difference` and `complement`, and
`subset?`, `superset?`, `disjoint?`, `intersect?` and `empty?` answer without materializing any member.

`EnumSet` includes `Enumerable`, so `map`, `select` and friends are available and return `Array`s, not sets.
Members are yielded in declaration order.
`size` and `length` count bits and cache the result; `count` is `Enumerable`'s and walks the members, the same split
that Ruby's own `Set` has.

## Maps

`Enummify::EnumHash` is a mutable map keyed by members of a single enum, stored as an array indexed by declaration
order, so a lookup is an array index rather than a hash of the key.

```ruby
# typed: strict

counts = Enummify::EnumHash.of(Status, [Status::PENDING, 1], [Status::RUNNING, 2])

counts[Status::PENDING] # => 1
counts[Status::SUCCEEDED] # => nil
counts[Status::SUCCEEDED] = 3
counts.keys # => an EnumSet of the three members
counts.to_h # => a plain Hash in declaration order
```

Keys are held in a bitmask alongside the values, so a stored `nil` is distinct from an absent key:

```ruby
# typed: strict

stored = { Status::PENDING => nil } #: Hash[Status, String?]
notes = Enummify::EnumHash.from(Status, stored)

notes.key?(Status::PENDING) # => true
notes[Status::PENDING] # => nil
notes.key?(Status::RUNNING) # => false
notes[Status::RUNNING] # => nil
```

`keys` returns an `EnumSet`, which makes key algebra across two maps a single `Integer` operation.

`fetch` has no default-argument form, only a block, because an optional value cannot be told apart from a stored
`nil` without an untyped sentinel.
It raises `KeyError` when the key is absent and no block is given.

`EnumHash.of` infers both types from the pairs written at the call site.
Sorbet cannot solve a type parameter out of a `Hash` literal, so an empty or literal-built map takes its types from a
`Hash` that is already annotated:

```ruby
# typed: strict

empty = {} #: Hash[Status, Integer]
counts = Enummify::EnumHash.from(Status, empty)
```

Entries are yielded in declaration order of their keys, not in insertion order.

## Scoped to one enum

Two enums number their members independently, so a set or a map belongs to exactly one enum.
Mixing them is a type error, and that is the only check:

```ruby
IN_FLIGHT.include?(OtherStatus::PENDING) # => rejected by Sorbet
IN_FLIGHT | OtherStatus.set(OtherStatus::PENDING) # => rejected by Sorbet
```

Nothing is re-checked at runtime, so code that defeats the type checker reads an unrelated bit or slot and gets a
meaningless answer rather than an exception.
This is the same trade as the rest of the library: static checking instead of runtime validation.

## Performance

Measured on Ruby 4.0.7, arm64-darwin25, against a 40-member enum.
The bitmask wins decisively on whole-set algebra and on memory, and loses slightly on the operations that stdlib
already does in C.

| Operation | vs. stdlib |
| --- | --- |
| `union`, `intersection` | 4–5.5× faster |
| chained `(a \| b) & c` | 5.7× faster |
| `subset?` | 4.3× faster |
| key-set intersection across two maps | 26× faster |
| `each`, `map` over a set | about even |
| `include?`, `size`, construction | 1.1–1.3× slower |
| `EnumHash#[]` | 1.0–1.2× slower |
| `EnumHash#[]=` | 1.5× slower |
| `EnumHash#each` | 2.4× slower |

Memory is where the representation pays off consistently:

| Container (40 members) | stdlib | Enummify |
| --- | --- | --- |
| set | `Set` 1232 B | `EnumSet` 80 B, or 440 B once iterated |
| map | `Hash` 1744 B | `EnumHash` 720 B |

A mask of 62 bits or fewer is an immediate `Integer` costing nothing beyond the object that holds it, so a set that
has not been iterated allocates no storage of its own.
Beyond 62 members Ruby promotes the mask to a Bignum, which allocates; `EnumHash` writes in particular slow down
there, because each write builds a new mask.

A set materializes and caches its member `Array` the first time it is iterated, because walking a mask in Ruby is
slower than iterating an `Array`.
Set algebra never materializes, which is what keeps chained operations cheap.

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
