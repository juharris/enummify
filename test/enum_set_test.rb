# typed: strict
# frozen_string_literal: true

require 'test/unit'
require_relative '../lib/enummify'

# Named fixtures keep diagnostics stable and support static member types.
module EnumSetTest
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

  class EnumSetTest < Test::Unit::TestCase
    #: () -> void
    def test_add_and_delete_return_new_sets
      original = Enummify::EnumSet.of(Status, Status::PENDING, Status::RUNNING)

      assert_equal(Enummify::EnumSet.of(Status, Status::PENDING, Status::RUNNING, Status::FAILED),
                   original.add(Status::FAILED))
      assert_equal(Enummify::EnumSet.of(Status, Status::RUNNING), original.delete(Status::PENDING))
      assert_equal(Enummify::EnumSet.of(Status, Status::PENDING, Status::RUNNING), original)

      # Adding a member already present and deleting an absent one both leave the set unchanged.
      assert_equal(original, original.add(Status::PENDING))
      assert_equal(original, original.delete(Status::FAILED))
    end

    #: () -> void
    def test_all_matches_every_member
      all = Enummify::EnumSet.all(Status)

      assert_equal(Status.values, all.to_a)
      assert_equal(Status.values.length, all.size)
      Status.values.each { |member| assert(all.include?(member)) }
    end

    #: () -> void
    def test_case_equality_matches_members
      in_flight = Enummify::EnumSet.of(Status, Status::PENDING, Status::RUNNING)

      result = case Status::RUNNING
               when in_flight then :flying
               else :landed
               end
      assert_equal(:flying, result)

      assert_equal(:landed, case Status::FAILED when in_flight then :flying else :landed end)
    end

    #: () -> void
    def test_complement_is_the_remaining_members
      in_flight = Enummify::EnumSet.of(Status, Status::PENDING, Status::RUNNING)
      finished = Enummify::EnumSet.of(Status, Status::SUCCEEDED, Status::FAILED)

      assert_equal(finished, ~in_flight)
      assert_equal(finished, in_flight.complement)
      assert_equal(in_flight, ~~in_flight)
      assert_equal(Enummify::EnumSet.all(Status), ~Enummify::EnumSet.none(Status))
      assert_equal(Enummify::EnumSet.none(Status), ~Enummify::EnumSet.all(Status))
    end

    #: () -> void
    def test_construction_is_restricted_to_factories
      # public_send reaches the private constructor the way a consumer would, rather than bypassing it with send.
      assert_raises(NoMethodError) { Enummify::EnumSet.public_send(:new, Status, 0) }
      assert_raises(NoMethodError) { Enummify::EnumSet.public_send(:mask_for, []) }
    end

    #: () -> void
    def test_difference_removes_members
      in_flight = Enummify::EnumSet.of(Status, Status::PENDING, Status::RUNNING)
      pending = Enummify::EnumSet.of(Status, Status::PENDING)
      running = Enummify::EnumSet.of(Status, Status::RUNNING)

      assert_equal(running, in_flight - pending)
      assert_equal(running, in_flight.difference(pending))
      assert_equal(in_flight, in_flight - Enummify::EnumSet.none(Status))
      assert_equal(Enummify::EnumSet.none(Status), in_flight - in_flight)
    end

    #: () -> void
    def test_each_yields_declaration_order
      # FAILED is declared last but sorts first, so a set built in reverse still yields declaration order.
      set = Enummify::EnumSet.of(Status, Status::FAILED, Status::PENDING)

      yielded = [] #: Array[Enummify::Enum]
      assert_same(set, set.each { |member| yielded << member })
      assert_equal([Status::PENDING, Status::FAILED], yielded)
      assert_equal([Status::PENDING, Status::FAILED], set.to_a)
    end

    #: () -> void
    def test_empty_enum_has_only_an_empty_set
      all = Enummify::EnumSet.all(EmptyStatus)

      assert_predicate(all, :empty?)
      assert_equal(0, all.size)
      assert_equal([], all.to_a)
      assert_equal(Enummify::EnumSet.none(EmptyStatus), all)
      assert_equal(all, ~all)
    end

    #: () -> void
    def test_enumerable_methods_return_arrays
      set = Enummify::EnumSet.of(Status, Status::SUCCEEDED, Status::PENDING)

      assert_equal(%w[pending succeeded], set.map(&:serialize))
      # select comes from Enumerable, so it returns an Array rather than another set.
      selected = set.select { |member| member == Status::PENDING }
      assert_instance_of(Array, selected)
      assert_equal([Status::PENDING], selected)
      assert_equal(Status::PENDING, set.find { |member| member == Status::PENDING })
      assert(set.any? { |member| member == Status::SUCCEEDED })
      assert_equal(2, set.count)
      # count is left to Enumerable, so its block and argument forms stay correct.
      assert_equal(1, set.count { |member| member == Status::PENDING })
      assert_equal(1, set.count(Status::PENDING))
    end

    #: () -> void
    def test_equality_is_scoped_to_the_enum_class
      pending = Enummify::EnumSet.of(Status, Status::PENDING)

      assert_equal(pending, Enummify::EnumSet.of(Status, Status::PENDING))
      assert(pending.eql?(Enummify::EnumSet.of(Status, Status::PENDING)))
      assert_equal(pending.hash, Enummify::EnumSet.of(Status, Status::PENDING).hash)
      assert_not_equal(pending, Enummify::EnumSet.of(Status, Status::RUNNING))
      # Both sets hold bit 0, so equality has to compare the enum as well as the mask.
      assert_not_equal(pending, Enummify::EnumSet.of(OtherStatus, OtherStatus::PENDING))
      assert_not_equal(pending, [Status::PENDING])
      assert_not_equal(pending, nil)
    end

    #: () -> void
    def test_freeze_caches_before_freezing
      set = Enummify::EnumSet.of(Status, Status::FAILED, Status::PENDING)

      assert_same(set, set.freeze)
      assert_frozen_pending_and_failed(set)
      # Freezing caches the members first, so a frozen set keeps reading one array.
      assert_same(set.to_a, set.to_a)

      # Set operations build new sets, so they work on a frozen set and return sets that are not frozen.
      union = set | Enummify::EnumSet.of(Status, Status::RUNNING)
      assert_not_predicate(union, :frozen?)
      assert_equal([Status::PENDING, Status::RUNNING, Status::FAILED], union.to_a)
      assert_equal(3, union.size)
    end

    #: () -> void
    def test_from_accepts_any_enumerable
      expected = Enummify::EnumSet.of(Status, Status::PENDING, Status::FAILED)

      assert_equal(expected, Enummify::EnumSet.from(Status, [Status::PENDING, Status::FAILED]))
      # Duplicates collapse, because a member sets the same bit twice.
      assert_equal(expected,
                   Enummify::EnumSet.from(Status, [Status::PENDING, Status::FAILED, Status::PENDING]))
      assert_equal(expected, Enummify::EnumSet.from(Status, expected))
      assert_equal(Enummify::EnumSet.none(Status), Enummify::EnumSet.from(Status, []))
    end

    #: () -> void
    def test_frozen_copies_read_their_members
      # Kernel#clone and Marshal.load freeze a copy without calling freeze, so each way of freezing is checked.
      assert_frozen_pending_and_failed(Enummify::EnumSet.of(Status, Status::FAILED, Status::PENDING).freeze.clone)
      assert_frozen_pending_and_failed(Enummify::EnumSet.of(Status, Status::FAILED, Status::PENDING).clone(freeze: true))
      dumped = Marshal.dump(Enummify::EnumSet.of(Status, Status::FAILED, Status::PENDING))
      # Sorbet's signature for Marshal.load predates its freeze keyword, so the call goes through Method#call.
      loaded = Marshal.method(:load).call(dumped, freeze: true) #: as Enummify::EnumSet[Status]
      assert_frozen_pending_and_failed(loaded)
    end

    #: () -> void
    def test_inspection_includes_class_and_members
      set = Enummify::EnumSet.of(Status, Status::FAILED, Status::PENDING)

      assert_equal('#<Enummify::EnumSet[EnumSetTest::Status]: ["pending", "failed"]>', set.inspect)
      assert_equal(set.inspect, set.to_s)
      assert_equal('#<Enummify::EnumSet[EnumSetTest::Status]: []>', Enummify::EnumSet.none(Status).inspect)
    end

    #: () -> void
    def test_intersection_keeps_shared_members
      in_flight = Enummify::EnumSet.of(Status, Status::PENDING, Status::RUNNING)
      started = Enummify::EnumSet.of(Status, Status::RUNNING, Status::SUCCEEDED)
      running = Enummify::EnumSet.of(Status, Status::RUNNING)

      assert_equal(running, in_flight & started)
      assert_equal(running, in_flight.intersection(started))
      assert_equal(Enummify::EnumSet.none(Status), in_flight & Enummify::EnumSet.none(Status))
    end

    #: () -> void
    def test_membership_tests_every_member
      in_flight = Enummify::EnumSet.of(Status, Status::PENDING, Status::RUNNING)

      assert(in_flight.include?(Status::PENDING))
      assert(in_flight.member?(Status::RUNNING))
      assert_false(in_flight.include?(Status::SUCCEEDED))
      assert_false(in_flight.include?(Status::FAILED))
      assert_false(Enummify::EnumSet.none(Status).include?(Status::PENDING))
    end

    #: () -> void
    def test_relations_compare_masks
      in_flight = Enummify::EnumSet.of(Status, Status::PENDING, Status::RUNNING)
      pending = Enummify::EnumSet.of(Status, Status::PENDING)
      finished = Enummify::EnumSet.of(Status, Status::SUCCEEDED, Status::FAILED)
      none = Enummify::EnumSet.none(Status)

      assert(pending.subset?(in_flight))
      assert_false(in_flight.subset?(pending))
      assert(in_flight.subset?(in_flight))
      assert(in_flight.superset?(pending))
      assert(none.subset?(in_flight))

      assert(in_flight.intersect?(pending))
      assert_false(in_flight.intersect?(finished))
      assert(in_flight.disjoint?(finished))
      assert_false(in_flight.disjoint?(pending))
    end

    #: () -> void
    def test_set_factory_builds_from_the_enum
      assert_equal(Enummify::EnumSet.of(Status, Status::PENDING, Status::RUNNING),
                   Status.set(Status::PENDING, Status::RUNNING))
      assert_equal(Enummify::EnumSet.of(Status, Status::PENDING), Status.set(Status::PENDING))

      # The member type comes from the arguments, so an empty set has to come from EnumSet.none instead.
      assert_raises(ArgumentError) { Status.send(:set) }
    end

    #: () -> void
    def test_sets_round_trip_across_the_immediate_boundary
      # A mask of 62 bits or fewer is an immediate Integer; beyond that Ruby promotes it to a Bignum.
      # Sizes on both sides of that boundary check that nothing depends on the representation.
      [1, 62, 63, 200].each do |size|
        enum = enum_of_size(size)
        members = enum.values
        all = Enummify::EnumSet.all(enum)

        assert_equal(size, all.size, "size #{size}")
        assert_equal(members, all.to_a, "members #{size}")
        assert_equal(all, Enummify::EnumSet.from(enum, members), "round trip #{size}")
        assert_equal(Enummify::EnumSet.none(enum), ~all, "complement #{size}")

        last = members.fetch(size - 1)
        only_last = Enummify::EnumSet.from(enum, [last])
        assert_equal(1, only_last.size, "last size #{size}")
        assert(only_last.include?(last), "last include #{size}")
        assert_equal(size - 1, (all - only_last).size, "difference #{size}")
      end
    end

    #: () -> void
    def test_size_counts_members
      assert_equal(0, Enummify::EnumSet.none(Status).size)
      assert_equal(1, Enummify::EnumSet.of(Status, Status::PENDING).size)
      assert_equal(2, Enummify::EnumSet.of(Status, Status::PENDING, Status::FAILED).length)
      assert_predicate(Enummify::EnumSet.none(Status), :empty?)
      assert_not_predicate(Enummify::EnumSet.of(Status, Status::PENDING), :empty?)
    end

    #: () -> void
    def test_symmetric_difference_keeps_unshared_members
      in_flight = Enummify::EnumSet.of(Status, Status::PENDING, Status::RUNNING)
      started = Enummify::EnumSet.of(Status, Status::RUNNING, Status::SUCCEEDED)

      assert_equal(Enummify::EnumSet.of(Status, Status::PENDING, Status::SUCCEEDED), in_flight ^ started)
      # A set differs from itself in nothing, which is the point of the assertion.
      # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands
      assert_equal(Enummify::EnumSet.none(Status), in_flight ^ in_flight)
      # rubocop:enable Lint/BinaryOperatorWithIdenticalOperands
    end

    #: () -> void
    def test_type_application_returns_the_class
      # Applying type arguments mirrors T::Generic#[], which lets a sorbet-runtime consumer name the type in a sig.
      assert_same(Enummify::EnumSet, Enummify::EnumSet[Status])
    end

    #: () -> void
    def test_union_combines_members
      pending = Enummify::EnumSet.of(Status, Status::PENDING)
      running = Enummify::EnumSet.of(Status, Status::RUNNING)
      in_flight = Enummify::EnumSet.of(Status, Status::PENDING, Status::RUNNING)

      assert_equal(in_flight, pending | running)
      assert_equal(in_flight, pending + running)
      assert_equal(in_flight, pending.union(running))
      # Union is idempotent, which is the point of the assertion.
      # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands
      assert_equal(pending, pending | pending)
      # rubocop:enable Lint/BinaryOperatorWithIdenticalOperands
      assert_equal(pending, pending | Enummify::EnumSet.none(Status))
    end

    private

    # Check that a frozen set of PENDING and FAILED answers every read, twice, so a second read cannot fail to cache.
    #: (Enummify::EnumSet[Status]) -> void
    def assert_frozen_pending_and_failed(set)
      assert_predicate(set, :frozen?)
      2.times do
        assert_equal(2, set.size)
        assert_equal([Status::PENDING, Status::FAILED], set.to_a)
        assert_equal(%w[pending failed], set.map(&:serialize))
        assert_equal('#<Enummify::EnumSet[EnumSetTest::Status]: ["pending", "failed"]>', set.inspect)
      end
      assert(set.include?(Status::FAILED))
      assert_false(set.include?(Status::RUNNING))
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
