# Contributing to Enummify

For installation and usage, see [README.md](README.md).

## Setup

Use Ruby 4.0.6, as pinned in `.ruby-version`, for local development.
Keep the runtime compatible with Ruby 3.2 and newer.
Ruby 3.2 introduced `Module#const_added`, which the gem uses for eager member registration.

Install development dependencies:

```shell
bundle install
```

## Making changes

The implementation lives in `lib/` and has no runtime dependencies.
Keep runtime type annotations in RBS comments without introducing `T` APIs or `sorbet-runtime` into the implementation.
Keep `# typed: strict` at the top of Ruby and RBI files, including tests.

When changing the public API, update both the source annotations and [rbi/enummify.rbi](rbi/enummify.rbi).
Use standard Sorbet `sig` declarations in the exported RBI so it works without experimental RBS support.
The exported RBI lets applications type-check the gem without including its implementation files.

Member registration happens eagerly through `const_added`.
Lookup and enumeration only read the registry.
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

## Style and typing

```shell
bundle exec rubocop --cache true
bundle exec srb tc
```

Type checks cover the library and runtime tests, along with valid usage and intentional errors such as passing another enum, a raw string, or a possibly missing member.
They also reject unknown member constants and invalid constructor arguments.
`bundle exec rake typecheck` also verifies each marked invalid call in `test/types/`.
In `test/types/invalid.rb`, place `# expect-type-error: CODE` immediately before the expression expected to fail.
The checker compares the exact diagnostic codes and line numbers.

The normal Sorbet configuration excludes the exported RBI so it cannot hide errors in the implementation.
The package check validates the installed RBI without experimental flags, then verifies the RBS consumer fixtures against it separately.

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
