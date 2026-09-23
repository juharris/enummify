# typed: strict
# frozen_string_literal: true

require 'test/unit'
require_relative '../lib/enummify'

# Named fixtures keep diagnostics stable and support static member types.
module EnumHashTest
  class EmptyStatus < Enummify::Enum
  end

  class OtherStatus < Enummify::Enum
    PENDING = new('pending') #: OtherStatus
  end

  # Members are deliberately not in alphabetical order, so tests that assert declaration order would fail if the
  # implementation sorted or hashed instead of walking ordinals.
  class Status < Enummify::Enum
    PENDING = new('pending') #: Status
    RUNNING = new('running') #: Status
    SUCCEEDED = new('succeeded') #: Status
    FAILED = new('failed') #: Status
  end

  class EnumHashTest < Test::Unit::TestCase
    #: () -> void
    def test_clear_removes_every_entry
      counts = counts_of([Status::PENDING, 1], [Status::RUNNING, 2])

      assert_same(counts, counts.clear)
      assert_predicate(counts, :empty?)
      assert_equal(0, counts.size)
      assert_nil(counts[Status::PENDING])
      assert_false(counts.key?(Status::PENDING))
      assert_equal(Enummify::EnumSet.none(Status), counts.keys)

      # The cleared map still accepts writes, so clearing did not shrink the slots allocated for the enum.
      counts[Status::FAILED] = 3
      assert_equal(3, counts[Status::FAILED])
    end

    #: () -> void
    def test_construction_is_restricted_to_factories
      # public_send reaches the private constructor the way a consumer would, rather than bypassing it with send.
      assert_raises(NoMethodError) { Enummify::EnumHash.public_send(:new, Status) }
    end

    #: () -> void
    def test_delete_returns_the_value_and_removes_the_key
      counts = counts_of([Status::PENDING, 1], [Status::RUNNING, 2])

      assert_equal(1, counts.delete(Status::PENDING))
      assert_false(counts.key?(Status::PENDING))
      assert_equal(1, counts.size)
      # Deleting an absent key reports nil rather than raising.
      assert_nil(counts.delete(Status::PENDING))
      assert_nil(counts.delete(Status::FAILED))
      assert_equal(counts_of([Status::RUNNING, 2]), counts)
    end

    #: () -> void
    def test_each_yields_declaration_order
      # FAILED is declared last but written first, so insertion order would give a different answer.
      counts = counts_of([Status::FAILED, 9], [Status::PENDING, 1])

      yielded = [] #: Array[[Enummify::Enum, Integer]]
      assert_same(counts, counts.each { |member, count| yielded << [member, count] })
      assert_equal([[Status::PENDING, 1], [Status::FAILED, 9]], yielded)

      paired = [] #: Array[[Enummify::Enum, Integer]]
      counts.each_pair { |member, count| paired << [member, count] }
      assert_equal(yielded, paired)
    end

    #: () -> void
    def test_empty_enum_has_only_an_empty_map
      # An empty map has no entry to infer the value type from, so the type comes from an already typed Hash.
      empty = {} #: Hash[EmptyStatus, Integer]
      counts = Enummify::EnumHash.from(EmptyStatus, empty)

      assert_predicate(counts, :empty?)
      assert_equal(0, counts.size)
      assert_equal({}, counts.to_h)
      assert_equal(Enummify::EnumSet.none(EmptyStatus), counts.keys)
    end

    #: () -> void
    def test_equality_is_scoped_to_the_enum_class
      counts = counts_of([Status::PENDING, 1])

      assert_equal(counts, counts_of([Status::PENDING, 1]))
      assert_not_equal(counts, counts_of([Status::PENDING, 2]))
      assert_not_equal(counts, counts_of([Status::RUNNING, 1]))
      assert_not_equal(counts, counts_of([Status::PENDING, 1], [Status::RUNNING, 2]))
      # Both maps write slot 0, so equality has to compare the enum as well as the entries.
      assert_not_equal(counts, Enummify::EnumHash.of(OtherStatus, [OtherStatus::PENDING, 1]))
      assert_not_equal(counts, { Status::PENDING => 1 })
      assert_not_equal(counts, nil)
    end

    #: () -> void
    def test_fetch_returns_calls_or_raises
      counts = counts_of([Status::PENDING, 1])

      assert_equal(1, counts.fetch(Status::PENDING))

      # Unlike Hash#fetch there is no default argument, because an optional value cannot be told apart from a
      # stored nil without an untyped sentinel. The block is called only when the key is absent.
      calls = 0
      assert_equal(1, counts.fetch(Status::PENDING) { calls += 1 })
      assert_equal(0, calls)
      assert_equal(7, counts.fetch(Status::FAILED) { calls += 7 })
      assert_equal(7, calls)

      # The block receives the missing key, matching Hash#fetch.
      assert_equal(-1, counts.fetch(Status::FAILED) { |member| member.equal?(Status::FAILED) ? -1 : 0 })

      error = assert_raises(KeyError) { counts.fetch(Status::FAILED) }
      assert_equal('key not found: #<EnumHashTest::Status: "failed">', error.message)
    end

    #: () -> void
    def test_from_copies_an_existing_hash
      source = { Status::PENDING => 1, Status::FAILED => 9 } #: Hash[Status, Integer]
      counts = Enummify::EnumHash.from(Status, source)

      assert_equal(counts_of([Status::PENDING, 1], [Status::FAILED, 9]), counts)
      # The map holds its own slots, so writing through it leaves the source Hash alone.
      counts[Status::PENDING] = 2
      assert_equal(1, source.fetch(Status::PENDING))

      # An inline annotation swallows the rest of the line, so the empty Hash is typed through a local.
      empty = {} #: Hash[Status, Integer]
      assert_predicate(Enummify::EnumHash.from(Status, empty), :empty?)
    end

    #: () -> void
    def test_inspection_includes_class_and_entries
      counts = counts_of([Status::FAILED, 9], [Status::PENDING, 1])

      assert_equal('#<Enummify::EnumHash[EnumHashTest::Status]: ' \
                   '{#<EnumHashTest::Status: "pending"> => 1, #<EnumHashTest::Status: "failed"> => 9}>',
                   counts.inspect)
      assert_equal(counts.inspect, counts.to_s)
      assert_equal('#<Enummify::EnumHash[EnumHashTest::Status]: {}>', counts_of.inspect)
    end

    #: () -> void
    def test_keys_are_a_set_and_track_writes
      counts = counts_of([Status::PENDING, 1])

      keys = counts.keys
      assert_equal(Enummify::EnumSet.of(Status, Status::PENDING), keys)
      # The set is cached, so repeated reads do not rebuild it.
      assert_same(keys, counts.keys)

      counts[Status::FAILED] = 9
      assert_equal(Enummify::EnumSet.of(Status, Status::PENDING, Status::FAILED), counts.keys)
      counts.delete(Status::PENDING)
      assert_equal(Enummify::EnumSet.of(Status, Status::FAILED), counts.keys)

      # Key algebra across two maps is a single Integer operation, which is the reason keys is a set.
      other = counts_of([Status::FAILED, 1], [Status::RUNNING, 2])
      assert_equal(Enummify::EnumSet.of(Status, Status::FAILED), counts.keys & other.keys)
    end

    #: () -> void
    def test_membership_distinguishes_a_stored_nil_from_an_absent_key
      # The value type has to allow nil for a stored nil to be distinguishable from an absent key.
      empty = {} #: Hash[Status, Integer?]
      counts = Enummify::EnumHash.from(Status, empty)
      counts[Status::PENDING] = nil

      assert(counts.key?(Status::PENDING))
      assert_nil(counts[Status::PENDING])
      assert_nil(counts.fetch(Status::PENDING))
      assert_equal(1, counts.size)
      assert_equal([Status::PENDING], counts.keys.to_a)
      assert_equal([nil], counts.values)

      assert_false(counts.key?(Status::FAILED))
      assert_nil(counts[Status::FAILED])
      assert_raises(KeyError) { counts.fetch(Status::FAILED) }

      # Deleting a stored nil reports nil as well, so the key set is what distinguishes the two.
      assert_nil(counts.delete(Status::PENDING))
      assert_false(counts.key?(Status::PENDING))
    end

    #: () -> void
    def test_membership_is_aliased_like_hash
      counts = counts_of([Status::PENDING, 1])

      assert(counts.key?(Status::PENDING))
      # The alias exists so the map reads like a Hash, so the test names it rather than the preferred spelling.
      assert(counts.has_key?(Status::PENDING)) # rubocop:disable Style/PreferredHashMethods
      assert(counts.include?(Status::PENDING))
      assert(counts.member?(Status::PENDING))
      assert_false(counts.key?(Status::FAILED))
    end

    #: () -> void
    def test_merge_combines_maps
      counts = counts_of([Status::PENDING, 1], [Status::RUNNING, 2])
      other = counts_of([Status::RUNNING, 20], [Status::FAILED, 9])

      merged = counts.merge(other)
      # The argument wins on a shared key, matching Hash#merge.
      assert_equal(counts_of([Status::PENDING, 1], [Status::RUNNING, 20], [Status::FAILED, 9]), merged)
      # merge leaves both operands alone.
      assert_equal(counts_of([Status::PENDING, 1], [Status::RUNNING, 2]), counts)

      assert_same(counts, counts.merge!(other))
      assert_equal(merged, counts)

      assert_equal(counts_of([Status::PENDING, 1], [Status::RUNNING, 20], [Status::FAILED, 9],
                             [Status::SUCCEEDED, 5]),
                   counts.merge!({ Status::SUCCEEDED => 5 }))
    end

    #: () -> void
    def test_of_builds_from_pairs
      counts = Enummify::EnumHash.of(Status, [Status::PENDING, 1], [Status::FAILED, 9])

      assert_equal(1, counts[Status::PENDING])
      assert_equal(9, counts[Status::FAILED])
      assert_equal(2, counts.size)
      # A repeated key keeps the last value written, matching Hash.
      assert_equal(2, Enummify::EnumHash.of(Status, [Status::PENDING, 1], [Status::PENDING, 2])[Status::PENDING])
    end

    #: () -> void
    def test_reads_and_writes
      counts = counts_of

      assert_predicate(counts, :empty?)
      assert_nil(counts[Status::PENDING])

      counts[Status::PENDING] = 1
      assert_equal(1, counts[Status::PENDING])
      counts[Status::PENDING] = 2
      assert_equal(2, counts[Status::PENDING])
      assert_equal(1, counts.size)

      counts.store(Status::FAILED, 9)
      assert_equal(9, counts[Status::FAILED])
      assert_equal(2, counts.length)
    end

    #: () -> void
    def test_slots_cover_every_member_of_a_large_enum
      # A presence mask beyond 62 bits is a Bignum, so a large enum checks that nothing depends on the
      # representation of the mask.
      [1, 62, 63, 200].each do |size|
        enum = enum_of_size(size)
        members = enum.values
        indexed = members.each_with_index.to_h #: Hash[Enummify::Enum, Integer]
        counts = Enummify::EnumHash.from(enum, indexed)

        assert_equal(size, counts.size, "size #{size}")
        assert_equal(members, counts.keys.to_a, "keys #{size}")
        assert_equal((0...size).to_a, counts.values, "values #{size}")

        last = members.fetch(size - 1)
        assert_equal(size - 1, counts.fetch(last), "last #{size}")
        assert_equal(size - 1, counts.delete(last), "delete #{size}")
        assert_equal(size - 1, counts.size, "size after delete #{size}")
      end
    end

    #: () -> void
    def test_to_h_and_values_follow_declaration_order
      counts = counts_of([Status::FAILED, 9], [Status::PENDING, 1])

      assert_equal({ Status::PENDING => 1, Status::FAILED => 9 }, counts.to_h)
      assert_equal([Status::PENDING, Status::FAILED], counts.to_h.keys)
      assert_equal([1, 9], counts.values)
      assert_equal([], counts_of.values)
    end

    #: () -> void
    def test_type_application_returns_the_class
      # Applying type arguments mirrors T::Generic#[], which lets a sorbet-runtime consumer name the type in a sig.
      assert_same(Enummify::EnumHash, Enummify::EnumHash[Status, Integer])
    end

    private

    # Build a map of Status to Integer, which most tests need and which spells out the type once.
    #: (*[Status, Integer]) -> Enummify::EnumHash[Status, Integer]
    def counts_of(*entries)
      # Sorbet cannot splat an array of unknown length into a rest parameter, so the pairs go through a Hash.
      Enummify::EnumHash.from(Status, entries.to_h)
    end

    # Build an enum with the given number of members, for sizes that are impractical to write out.
    #: (Integer) -> singleton(Enummify::Enum)
    def enum_of_size(size)
      Class.new(Enummify::Enum) do
        size.times { |index| const_set(:"MEMBER_#{index}", new) }
      end
    end
  end
end
