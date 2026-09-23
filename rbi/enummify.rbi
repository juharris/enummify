# typed: strict
# frozen_string_literal: true

module Enummify
  # A typed set of immutable, named instances with string serialization.
  class Enum
    extend T::Sig

    sig { params(serialized: String).returns(T.attached_class) }
    def self.deserialize(serialized); end

    class << self
      alias _load deserialize
    end

    sig do
      type_parameters(:M)
        .params(
          member: T.all(T.type_parameter(:M), Enummify::Enum),
          members: T.all(T.type_parameter(:M), Enummify::Enum)
        )
        .returns(EnumSet[T.type_parameter(:M)])
    end
    def self.set(member, *members); end

    sig { params(serialized: String).returns(T.nilable(T.attached_class)) }
    def self.try_deserialize(serialized); end

    sig { returns(T::Array[T.attached_class]) }
    def self.values; end

    sig { params(_depth: Integer).returns(String) }
    def _dump(_depth); end

    # The member's bit in EnumSet and EnumHash masks.
    # It is public only so those classes can read it quickly, and is not meant for use outside Enummify.
    sig { returns(Integer) }
    def bit; end

    sig { params(freeze: T.nilable(T::Boolean)).returns(T.self_type) }
    def clone(freeze: true); end

    sig { returns(T.self_type) }
    def dup; end

    sig { returns(String) }
    def inspect; end

    # The member's 0-based position in declaration order.
    # It is public only so EnumSet and EnumHash can read it quickly, and is not meant for use outside Enummify.
    sig { returns(Integer) }
    def ordinal; end

    sig { returns(String) }
    def serialize; end

    sig { returns(String) }
    def to_s; end

    private

    sig { params(serialized: T.nilable(String)).void }
    def initialize(serialized = nil); end
  end

  # A mutable map keyed by members of a single enum, stored as an array indexed by declaration order.
  class EnumHash
    extend T::Generic
    extend T::Sig

    Key = type_member
    Value = type_member

    sig do
      type_parameters(:M, :V)
        .params(
          enum_class: T.all(T::Class[T.type_parameter(:M)], T.class_of(Enummify::Enum)),
          entries: T::Hash[T.type_parameter(:M), T.type_parameter(:V)]
        )
        .returns(EnumHash[T.type_parameter(:M), T.type_parameter(:V)])
    end
    def self.from(enum_class, entries); end

    sig do
      type_parameters(:M, :V)
        .params(
          enum_class: T.all(T::Class[T.type_parameter(:M)], T.class_of(Enummify::Enum)),
          entries: [T.all(T.type_parameter(:M), Enummify::Enum), T.type_parameter(:V)]
        )
        .returns(EnumHash[T.type_parameter(:M), T.type_parameter(:V)])
    end
    def self.of(enum_class, *entries); end

    sig { params(member: T.all(Key, Enummify::Enum)).returns(T.nilable(Value)) }
    def [](member); end

    sig { params(member: T.all(Key, Enummify::Enum), value: Value).void }
    def []=(member, value); end

    sig { params(other: T.untyped).returns(T::Boolean) }
    def ==(other); end

    sig { returns(T.self_type) }
    def clear; end

    sig { params(member: T.all(Key, Enummify::Enum)).returns(T.nilable(Value)) }
    def delete(member); end

    sig { params(block: T.proc.params(member: T.all(Key, Enummify::Enum), value: Value).void).returns(T.self_type) }
    def each(&block); end

    sig { returns(T::Boolean) }
    def empty?; end

    sig do
      params(
        member: T.all(Key, Enummify::Enum),
        block: T.nilable(T.proc.params(member: T.all(Key, Enummify::Enum)).returns(Value))
      ).returns(Value)
    end
    def fetch(member, &block); end

    sig { returns(String) }
    def inspect; end

    sig { params(member: T.all(Key, Enummify::Enum)).returns(T::Boolean) }
    def key?(member); end

    sig { returns(EnumSet[T.all(Key, Enummify::Enum)]) }
    def keys; end

    sig { params(entries: T.any(EnumHash[Key, Value], T::Hash[Key, Value])).returns(EnumHash[Key, Value]) }
    def merge(entries); end

    sig { params(entries: T.any(EnumHash[Key, Value], T::Hash[Key, Value])).returns(T.self_type) }
    def merge!(entries); end

    sig { returns(Integer) }
    def size; end

    sig { returns(T::Hash[Key, Value]) }
    def to_h; end

    sig { returns(String) }
    def to_s; end

    sig { returns(T::Array[Value]) }
    def values; end

    alias each_pair each
    alias has_key? key?
    alias include? key?
    alias length size
    alias member? key?
    alias store []=
  end

  # An immutable set of members of a single enum, stored as one Integer bitmask.
  class EnumSet
    extend T::Generic
    extend T::Sig
    include Enumerable

    Elem = type_member

    sig do
      type_parameters(:M)
        .params(enum_class: T.all(T::Class[T.type_parameter(:M)], T.class_of(Enummify::Enum)))
        .returns(EnumSet[T.type_parameter(:M)])
    end
    def self.all(enum_class); end

    sig do
      type_parameters(:M)
        .params(
          enum_class: T.all(T::Class[T.type_parameter(:M)], T.class_of(Enummify::Enum)),
          members: T::Enumerable[T.all(T.type_parameter(:M), Enummify::Enum)]
        )
        .returns(EnumSet[T.type_parameter(:M)])
    end
    def self.from(enum_class, members); end

    sig do
      type_parameters(:M)
        .params(enum_class: T.all(T::Class[T.type_parameter(:M)], T.class_of(Enummify::Enum)))
        .returns(EnumSet[T.type_parameter(:M)])
    end
    def self.none(enum_class); end

    sig do
      type_parameters(:M)
        .params(
          enum_class: T.all(T::Class[T.type_parameter(:M)], T.class_of(Enummify::Enum)),
          members: T.all(T.type_parameter(:M), Enummify::Enum)
        )
        .returns(EnumSet[T.type_parameter(:M)])
    end
    def self.of(enum_class, *members); end

    sig { params(other: EnumSet[Elem]).returns(EnumSet[Elem]) }
    def &(other); end

    sig { params(other: EnumSet[Elem]).returns(EnumSet[Elem]) }
    def +(other); end

    sig { params(other: EnumSet[Elem]).returns(EnumSet[Elem]) }
    def -(other); end

    sig { params(other: T.untyped).returns(T::Boolean) }
    def ==(other); end

    sig { params(member: T.untyped).returns(T::Boolean) }
    def ===(member); end

    sig { params(other: EnumSet[Elem]).returns(EnumSet[Elem]) }
    def ^(other); end

    sig { params(other: EnumSet[Elem]).returns(EnumSet[Elem]) }
    def |(other); end

    sig { returns(EnumSet[Elem]) }
    def ~; end

    sig { params(member: T.all(Elem, Enummify::Enum)).returns(EnumSet[Elem]) }
    def add(member); end

    sig { params(member: T.all(Elem, Enummify::Enum)).returns(EnumSet[Elem]) }
    def delete(member); end

    sig { params(other: EnumSet[Elem]).returns(EnumSet[Elem]) }
    def difference(other); end

    sig { params(other: EnumSet[Elem]).returns(T::Boolean) }
    def disjoint?(other); end

    sig { params(block: T.proc.params(member: Elem).void).returns(T.self_type) }
    def each(&block); end

    sig { returns(T::Boolean) }
    def empty?; end

    sig { params(other: T.untyped).returns(T::Boolean) }
    def eql?(other); end

    sig { returns(Integer) }
    def hash; end

    sig { params(member: Elem).returns(T::Boolean) }
    def include?(member); end

    sig { returns(String) }
    def inspect; end

    sig { params(other: EnumSet[Elem]).returns(T::Boolean) }
    def intersect?(other); end

    sig { params(other: EnumSet[Elem]).returns(EnumSet[Elem]) }
    def intersection(other); end

    sig { returns(Integer) }
    def size; end

    sig { params(other: EnumSet[Elem]).returns(T::Boolean) }
    def subset?(other); end

    sig { params(other: EnumSet[Elem]).returns(T::Boolean) }
    def superset?(other); end

    sig { returns(T::Array[Elem]) }
    def to_a; end

    sig { returns(String) }
    def to_s; end

    sig { params(other: EnumSet[Elem]).returns(EnumSet[Elem]) }
    def union(other); end

    alias complement ~
    alias length size
    alias member? include?
  end
end
