# typed: strict
# frozen_string_literal: true

module Enummify
  # An immutable set of members of a single enum, stored as one Integer bitmask.
  #
  # Each member occupies the bit at its declaration index, so union, intersection, difference and subset tests are
  # single Integer operations rather than hash walks.
  # A mask for an enum with 62 or fewer members is an immediate value, so such a set holds no heap-allocated storage.
  #
  # Operations take a set of the same enum and are checked statically, so nothing is re-checked at runtime.
  # Two enums number their members independently, so combining sets of different enums is a type error, and a
  # consumer that defeats the type checker gets a meaningless result rather than an exception.
  #
  # Sets are immutable: every operation returns a new set.
  # They are not frozen, because the member array and size are computed on first use and cached.
  # Materializing eagerly instead would cost far more than the bitmask saves.
  # Freezing a set caches both first, so a frozen set reads them as quickly as one that is not frozen.
  #
  # The type parameter is named Elem so that including Enumerable supplies map, select and friends with the member
  # type already bound.
  #: [Elem]
  class EnumSet
    include Enumerable

    # Accept type arguments at runtime without depending on sorbet-runtime.
    # This matches T::Generic#[], which also ignores its arguments and returns self, so a consumer can write
    # EnumSet[Status] inside a sig.
    #: (*untyped) -> singleton(EnumSet)
    def self.[](*)
      self
    end

    # Build the set of every member of the enum.
    #: [M < Enummify::Enum] (Class[M] & singleton(Enummify::Enum)) -> EnumSet[M]
    def self.all(enum_class)
      new(enum_class, (1 << enum_class.values.length) - 1)
    end

    # Build a set from a collection of members, for callers that already have one.
    # Enumerable is covariant in its element, so an Array of a specific member type is accepted here.
    #: [M < Enummify::Enum] (Class[M] & singleton(Enummify::Enum), Enumerable[M & Enummify::Enum]) -> EnumSet[M]
    def self.from(enum_class, members)
      new(enum_class, mask_for(members))
    end

    # Build the empty set for the enum.
    #: [M < Enummify::Enum] (Class[M] & singleton(Enummify::Enum)) -> EnumSet[M]
    def self.none(enum_class)
      new(enum_class, 0)
    end

    # Build a set from the given members.
    #: [M < Enummify::Enum] (Class[M] & singleton(Enummify::Enum), *(M & Enummify::Enum)) -> EnumSet[M]
    def self.of(enum_class, *members)
      new(enum_class, mask_for(members))
    end

    # Fold members into a bitmask.
    #: (Enumerable[Enummify::Enum]) -> Integer
    def self.mask_for(members)
      mask = 0
      members.each do |member|
        mask |= member.bit
      end
      mask
    end

    private_class_method :mask_for, :new

    #: (EnumSet[Elem]) -> EnumSet[Elem]
    def &(other)
      derive(@mask & other.mask)
    end

    #: (EnumSet[Elem]) -> EnumSet[Elem]
    def +(other)
      derive(@mask | other.mask)
    end

    #: (EnumSet[Elem]) -> EnumSet[Elem]
    def -(other)
      derive(@mask & ~other.mask)
    end

    # Equality accepts any object, so unlike the set operations it checks what it was given.
    #: (untyped) -> bool
    def ==(other)
      return false unless other.is_a?(EnumSet)

      other.enum_class.equal?(@enum_class) && other.mask == @mask
    end

    # Support `case member when SOME_SET`.
    #: (untyped) -> bool
    def ===(member)
      include?(member)
    end

    #: (EnumSet[Elem]) -> EnumSet[Elem]
    def ^(other)
      derive(@mask ^ other.mask)
    end

    #: (EnumSet[Elem]) -> EnumSet[Elem]
    def |(other)
      derive(@mask | other.mask)
    end

    # Return the set of this enum's members that this set does not contain.
    #: () -> EnumSet[Elem]
    def ~
      derive(((1 << @enum_class.values.length) - 1) ^ @mask)
    end

    # Return a set that also contains the member.
    #: (Elem & Enummify::Enum) -> EnumSet[Elem]
    def add(member)
      derive(@mask | member.bit)
    end

    # Return a set without the member.
    #: (Elem & Enummify::Enum) -> EnumSet[Elem]
    def delete(member)
      derive(@mask & ~member.bit)
    end

    #: (EnumSet[Elem]) -> EnumSet[Elem]
    def difference(other)
      derive(@mask & ~other.mask)
    end

    #: (EnumSet[Elem]) -> bool
    def disjoint?(other)
      (@mask & other.mask).zero?
    end

    # @override
    #: () { (Elem) -> void } -> self
    def each(&)
      to_a.each(&)
      self
    end

    #: () -> bool
    def empty?
      @mask.zero?
    end

    #: (untyped) -> bool
    def eql?(other)
      self == other
    end

    # Freeze the set, first caching its members and size.
    #: () -> self
    def freeze
      members
      size
      super
    end

    #: () -> Integer
    def hash
      [@enum_class, @mask].hash
    end

    # Masking by the member's bit measured faster than Set#include? for every enum of 62 or fewer members, whose masks
    # are immediate Integers, and indexing the mask by ordinal did not in the interpreter.
    # Enumerable#include? takes any member type, so narrowing the parameter is declared incompatible rather than cast
    # inside, because the local that a cast needs measured 7 ns slower in the interpreter.
    # Enums of more than 62 members are not a performance target, so masking is kept even though masking their Bignum
    # masks allocates, which indexing by ordinal would not.
    # @override(allow_incompatible: true)
    #: (Elem & Enummify::Enum) -> bool
    def include?(member)
      @mask & member.bit != 0
    end

    #: () -> String
    def inspect
      "#<Enummify::EnumSet[#{@enum_class.name}]: #{members.map(&:serialize).inspect}>"
    end

    #: (EnumSet[Elem]) -> bool
    def intersect?(other)
      !(@mask & other.mask).zero?
    end

    #: (EnumSet[Elem]) -> EnumSet[Elem]
    def intersection(other)
      derive(@mask & other.mask)
    end

    #: () -> Integer
    def size
      @size || count_members
    end

    #: (EnumSet[Elem]) -> bool
    def subset?(other)
      @mask & other.mask == @mask
    end

    #: (EnumSet[Elem]) -> bool
    def superset?(other)
      mask = other.mask
      @mask & mask == mask
    end

    # @override
    #: () -> Array[Elem]
    def to_a
      members #: as Array[Elem]
    end

    #: () -> String
    def to_s
      inspect
    end

    #: (EnumSet[Elem]) -> EnumSet[Elem]
    def union(other)
      derive(@mask | other.mask)
    end

    alias complement ~
    alias length size
    alias member? include?

    protected

    # Exposed to sibling sets so operations can read the other side without widening the public API.
    #: singleton(Enummify::Enum)
    attr_reader :enum_class

    #: Integer
    attr_reader :mask

    private

    # Count the members and cache the count.
    # Ruby has no popcount. Counting "1" in the binary representation measured fastest for small and large masks.
    #: () -> Integer
    def count_members
      counted = @mask.to_s(2).count('1')
      # Kernel#clone and Marshal.load with freeze: true freeze a set without calling freeze, so such a set counts every
      # time.
      return counted if frozen?

      @size = counted
    end

    # Build a sibling set over the same enum.
    #: (Integer) -> EnumSet[Elem]
    def derive(mask)
      EnumSet.send(:new, @enum_class, mask) #: as EnumSet[Elem]
    end

    #: (singleton(Enummify::Enum), Integer) -> void
    def initialize(enum_class, mask)
      @enum_class = enum_class
      @mask = mask
      @members = nil #: Array[Enummify::Enum]?
      @size = nil #: Integer?
    end

    # Materialize the members once and cache them.
    # Walking the mask is slower than iterating an Array, so every iteration after the first reads the cache.
    # Extracting the lowest set bit costs one step per present member and yields declaration order.
    #: () -> Array[Enummify::Enum]
    def members
      cached = @members
      return cached if cached

      materialized = []
      values = @enum_class.values
      remaining = @mask
      while remaining != 0
        lowest = remaining & -remaining
        materialized << values[lowest.bit_length - 1]
        remaining ^= lowest
      end
      materialized.freeze
      # Kernel#clone and Marshal.load with freeze: true freeze a set without calling freeze, so such a set materializes
      # every time.
      return materialized if frozen?

      @members = materialized
    end
  end
end
