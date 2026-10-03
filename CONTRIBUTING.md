# Contributing to Enummify

For installation and usage, see [README.md](README.md).

## Setup

Use the Ruby version pinned in `.ruby-version`, for local development.
Keep the runtime compatible with Ruby 3.2 and newer.
Ruby 3.2 introduced `Module#const_added`, which the gem uses for eager member registration.

Install development dependencies:

```shell
bundle install
```

## Making changes

Keep `# typed: strict` at the top of Ruby and RBI files, including tests.

When changing the public API, update both the source annotations and [rbi/enummify.rbi](rbi/enummify.rbi).
Use standard Sorbet `sig` declarations in the exported RBI so it works without experimental RBS support.
The exported RBI lets applications type-check the gem without including its implementation files.

Preserve the behavior documented in the README.

## Testing

Run all checks before submitting a change:

```shell
bundle exec rake
```

This runs runtime tests, RuboCop, type checks, and installed-package checks.
To run only the runtime tests:

```shell
bundle exec rake test
```

### Benchmarks

The [Performance](README.md#performance) numbers in the README come from the scripts in [benchmark/](benchmark/).
Re-run them after a change to `Enum`, `EnumSet` or `EnumHash`, and update the README from their output:

```shell
bundle exec rake benchmark
```

This runs every script under the interpreter and then under YJIT, because the two disagree on which operations win.
A full run takes several minutes.
To run one script in one mode:

```shell
bundle exec ruby benchmark/enum_set_benchmark.rb
bundle exec ruby --yjit benchmark/enum_set_benchmark.rb
```

Each script prints Markdown tables comparing `Set` or `Hash` against its Enummify counterpart for enums of 8, 40, and 62 members.
62 is the largest enum whose masks are immediate `Integer`s, and larger enums are not a performance target.
Timings are the fastest of several rounds, with the cost of the timing loop itself subtracted.
Numbers vary between machines, so compare runs from the same machine.

## Style and typing

```shell
bundle exec rubocop --cache true
bundle exec srb tc
```

Apply style fixes:

```shell
bundle exec rubocop --autocorrect --cache true
```

Preserve one sentence per line in Markdown prose and avoid reflowing it with formatters.

## Building

```shell
bundle exec rake build
```

Verify the built gem in an isolated installation, including running its usage example with automatic gem loading disabled and type-checking consumers against only its packaged RBI:

```shell
bundle exec rake test:package
```

This task builds the gem before checking it.

## Publishing

See the [workflow](https://github.com/juharris/enummify/blob/main/.github/workflows/build_test.yml) for automated checks and publishing.

Before the first release, register a [pending trusted publisher](https://rubygems.org/profile/oidc/pending_trusted_publishers) for gem `enummify`, repository `juharris/enummify`, and workflow `build_test.yml`.
Leave the environment field empty, matching this workflow.

Bump `Enummify::VERSION` in `lib/enummify/version.rb` to release a new version.
Run `bundle install` after the version change and commit the updated `Gemfile.lock` with it.
Run `bundle exec rake` before submitting the release change.
