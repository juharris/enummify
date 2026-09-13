# typed: strict
# frozen_string_literal: true

require 'test/unit'
require_relative '../lib/enummify'

# Named fixtures support static member types and Marshal class resolution.
module EnumTest
  class DefaultStatus < Enummify::Enum
    FROM_NIL = new(nil) #: DefaultStatus
    PENDING = new #: DefaultStatus
    RUNNING = new #: DefaultStatus
  end

  class OtherStatus < Enummify::Enum
    PENDING = new('pending') #: OtherStatus
  end

  class Status < Enummify::Enum
    PENDING = new('pending') #: Status
    RUNNING = new('running') #: Status
  end

  class EnumTest < Test::Unit::TestCase
    #: -> void
    def test_aliases_are_rejected
      enum = enum_with_value('value')

      assert_raises(ArgumentError) { enum.const_set(:ALIAS, enum_member(enum, :VALUE)) }
      assert_same(enum_member(enum, :VALUE), enum.deserialize('value'))
    end

    #: () -> void
    def test_case_matches_members
      result = case Status::RUNNING
               when Status::PENDING then :waiting
               when Status::RUNNING then :active
               end

      assert_equal(:active, result)
    end

    #: () -> void
    def test_copying_preserves_identity
      fixture_members.each do |value|
        assert_same(value, value.dup)
        assert_same(value, value.clone)
        assert_same(value, value.clone(freeze: false))
        assert_predicate(value, :frozen?)
      end
    end

    #: () -> void
    def test_declarations_are_ready_before_first_read
      [nil, 'value'].each do |serialization|
        enum = enum_with_value(serialization)
        expected = serialization || 'VALUE'

        assert_equal([enum_member(enum, :VALUE)], enum.values)
        assert_same(enum_member(enum, :VALUE), enum.deserialize(expected))
        assert_same(enum_member(enum, :VALUE), enum.try_deserialize(expected))
      end
    end

    #: () -> void
    def test_default_serialization_preserves_constant_names
      assert_equal('PENDING', DefaultStatus::PENDING.serialize)
      assert_equal('RUNNING', DefaultStatus::RUNNING.serialize)
      assert_equal('FROM_NIL', DefaultStatus::FROM_NIL.serialize)
    end

    #: () -> void
    def test_deserialization_preserves_canonical_identity
      fixture_members.each do |value|
        assert_same(value, value.class.deserialize(value.serialize.dup))
        assert_same(value, value.class.try_deserialize(value.serialize.dup))
      end
    end

    #: () -> void
    def test_deserialization_reports_unknown_values
      ['missing', 'PENDING', ''].each do |value|
        assert_raises(ArgumentError) { Status.deserialize(value) }
        assert_nil(Status.try_deserialize(value))
      end
    end

    #: () -> void
    def test_duplicate_serializations_are_rejected
      [%w[duplicate duplicate], [nil, 'FIRST'], ['SECOND', nil]].each do |first_serialization, second_serialization|
        enum = Class.new(Enummify::Enum)
        first = declare_member(enum, :FIRST, first_serialization)

        assert_raises(ArgumentError) { declare_member(enum, :SECOND, second_serialization) }
        assert_same(first, enum.deserialize(first.serialize))
      end
    end

    #: () -> void
    def test_empty_enum_values_are_memoized
      enum = Class.new(Enummify::Enum)
      empty_values = enum.values
      assert_equal([], empty_values)
      assert_same(empty_values, enum.values)
      assert_raises(ArgumentError) { enum.deserialize('value') }
      assert_nil(enum.try_deserialize('value'))
    end

    #: () -> void
    def test_equality_is_scoped_to_the_enum_class
      assert_not_equal(Status::PENDING, OtherStatus::PENDING)
      assert_not_equal(Status::PENDING, Status::RUNNING)
      assert_not_equal(Status::PENDING, 'pending')
      assert_equal(Status::PENDING, Status.deserialize('pending'))

      indexed = { Status::PENDING => :status, OtherStatus::PENDING => :other_status }
      assert_equal(2, indexed.size)
      assert_equal(:status, indexed[Status.deserialize('pending')])
      assert_equal(:other_status, indexed[OtherStatus.deserialize('pending')])
    end

    #: () -> void
    def test_inspection_includes_class_and_serialization
      inspected = Status::PENDING.inspect

      assert_include(inspected, Status.name)
      assert_include(inspected, 'pending')
      assert_equal(inspected, Status.deserialize('pending').inspect)
      assert_not_match(/0x[0-9a-f]+/i, inspected)
    end

    #: () -> void
    def test_marshal_preserves_identity
      members = fixture_members
      restored = Marshal.load(Marshal.dump(members)) #: as Array[Enummify::Enum]

      assert_equal(members.length, restored.length)
      members.each_with_index do |member, index|
        assert_same(member, restored[index])
        assert_predicate(restored[index], :frozen?)
      end
    end

    #: () -> void
    def test_members_are_frozen
      fixture_members.each do |value|
        assert_predicate(value, :frozen?)
        assert_predicate(value.serialize, :frozen?)
        assert_raises(FrozenError) { value.instance_variable_set(:@extra, true) }
      end
    end

    #: () -> void
    def test_registries_are_independent
      enum = enum_with_value('first')
      other_enum = enum_with_value('first')
      declare_member(enum, :SECOND)

      assert_equal([enum_member(enum, :VALUE), enum_member(enum, :SECOND)], enum.values)
      assert_same(enum_member(enum, :SECOND), enum.deserialize('SECOND'))
      assert_same(enum_member(enum, :VALUE), enum.try_deserialize('first'))
      assert_equal([enum_member(other_enum, :VALUE)], other_enum.values)
      assert_same(enum_member(other_enum, :VALUE), other_enum.deserialize('first'))
      assert_nil(other_enum.try_deserialize('SECOND'))
    end

    #: () -> void
    def test_serialization_is_an_immutable_copy
      source = String.new('mutable')
      enum = enum_with_value(source)
      source.replace('changed')

      assert_equal('mutable', enum_member(enum, :VALUE).serialize)
      assert_predicate(enum_member(enum, :VALUE).serialize, :frozen?)
      assert_raises(FrozenError) { enum_member(enum, :VALUE).serialize.replace('changed') }
      assert_same(enum_member(enum, :VALUE), enum.deserialize('mutable'))
      assert_nil(enum.try_deserialize('changed'))
    end

    #: () -> void
    def test_serialization_preserves_explicit_string_values
      ['', 'UPPER_case', 'with spaces', "line\nbreak"].each do |serialization|
        value = enum_member(enum_with_value(serialization), :VALUE)

        assert_equal(serialization, value.serialize)
        assert_equal(serialization, value.to_s)
      end
    end

    #: -> void
    def test_values
      values = Status.values
      assert_same(Status.values, values)
      assert(values.frozen?)
    end

    #: () -> void
    def test_values_is_memoized_in_definition_order
      enum = Class.new(Enummify::Enum) do
        new('discarded')
        const_set(:ZULU, new('last'))
        const_set(:ALPHA, new('first'))
      end

      members = [enum_member(enum, :ZULU), enum_member(enum, :ALPHA)]
      values = enum.values
      assert_equal(members, values)

      assert_same(values, enum.values)
      assert_nil(enum.try_deserialize('discarded'))
    end

    private

    #: (singleton(Enummify::Enum), Symbol, ?String?) -> Enummify::Enum
    def declare_member(enum, name, serialization = nil)
      enum.const_set(name, enum.new(serialization)) #: as Enummify::Enum
    end

    #: (singleton(Enummify::Enum), Symbol) -> Enummify::Enum
    def enum_member(enum, name)
      enum.const_get(name, false) #: as Enummify::Enum
    end

    #: (?String?) -> singleton(Enummify::Enum)
    def enum_with_value(serialization = nil)
      Class.new(Enummify::Enum) do
        const_set(:VALUE, new(serialization))
      end
    end

    #: () -> Array[Enummify::Enum]
    def fixture_members
      DefaultStatus.values + Status.values + OtherStatus.values
    end
  end
end
