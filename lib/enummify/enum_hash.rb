# typed: strict
# frozen_string_literal: true

module Enummify
  # A mutable map keyed by members of a single enum, stored as an array indexed by declaration order.
  #
  # A member's ordinal is its slot, so a lookup is an array index rather than a hash of the key.
  # Keys are held in a bitmask alongside the values, which keeps a stored nil distinct from an absent key and makes
  # the key set free to compute.
  #
  # Keys are checked statically, so nothing is re-checked at runtime.
  # A key of another enum is a type error, and a consumer that defeats the type checker overwrites an unrelated slot.
  #
  # Entries are yielded in declaration order, not insertion order.
  #: [Key, Value]
  class EnumHash
    # Accept type arguments at runtime without depending on sorbet-runtime.
    # This matches T::Generic#[], which also ignores its arguments and returns self, so a consumer can write
    # EnumHash[Status, Integer] inside a sig.
    #: (*untyped) -> singleton(EnumHash)
    def self.[](*)
      self
    end

    # Build a map from a Hash whose type is already declared, which infers both the key and the value type.
    # Sorbet cannot solve a type parameter out of a Hash literal, so a literal written at the call site yields an
    # untyped map and its keys go unchecked.
    # EnumHash.of infers from a literal, so prefer it unless the Hash is already typed.
    #: [M < Enummify::Enum, V] (Class[M] & singleton(Enummify::Enum), Hash[M, V]) -> EnumHash[M, V]
    def self.from(enum_class, entries)
      result = new(enum_class) #: EnumHash[M, V]
      result.merge!(entries)
      result
    end

    # Build a map from key and value pairs, which infers both types even when they are written at the call site.
    #: [M < Enummify::Enum, V] (Class[M] & singleton(Enummify::Enum), *[M & Enummify::Enum, V]) -> EnumHash[M, V]
    def self.of(enum_class, *entries)
      result = new(enum_class) #: EnumHash[M, V]
      entries.each { |member, value| result[member] = value }
      result
    end

    private_class_method :new

    #: (Key & Enummify::Enum) -> Value?
    def [](member)
      # Reading the ordinal inline is deliberate.
      # Moving this read into a helper method measured slower than a plain Hash lookup, erasing the gain entirely.
      @entries[member.instance_variable_get(:@ordinal)]
    end

    #: (Key & Enummify::Enum, Value) -> void
    def []=(member, value)
      ordinal = member.instance_variable_get(:@ordinal)
      @entries[ordinal] = value
      @present |= 1 << ordinal
      @keys = nil
    end

    # Equality accepts any object, so unlike the keyed operations it checks what it was given.
    #: (untyped) -> bool
    def ==(other)
      return false unless other.is_a?(EnumHash)

      other.enum_class.equal?(@enum_class) && other.present == @present && other.entries == @entries
    end

    # Remove every entry, keeping the capacity already allocated for this enum.
    #: () -> self
    def clear
      @entries = Array.new(@entries.length)
      @present = 0
      @keys = nil
      self
    end

    # Remove an entry and return the value it held, or nil when the key was absent.
    #: (Key & Enummify::Enum) -> Value?
    def delete(member)
      ordinal = member.instance_variable_get(:@ordinal)
      return nil unless @present[ordinal] == 1

      value = @entries[ordinal]
      @entries[ordinal] = nil
      @present &= ~(1 << ordinal)
      @keys = nil
      value
    end

    # Yield each present key and its value in declaration order.
    #: () { (Key & Enummify::Enum, Value) -> void } -> self
    def each(&)
      keys.to_a.each do |member|
        # Only present keys are yielded, so the slot holds a value that was written rather than an empty slot.
        value = @entries[member.instance_variable_get(:@ordinal)] #: as Value
        yield(member, value)
      end
      self
    end

    #: () -> bool
    def empty?
      @present.zero?
    end

    # Return the value for a member, calling the block or raising KeyError when the key is absent.
    #: (Key & Enummify::Enum) ?{ (Key & Enummify::Enum) -> Value } -> Value
    def fetch(member, &block)
      ordinal = member.instance_variable_get(:@ordinal)
      if @present[ordinal] == 1
        # A present key was written, so the slot holds a value rather than an empty slot.
        value = @entries[ordinal] #: as Value
        return value
      end
      return block.call(member) if block

      raise KeyError, "key not found: #{member.inspect}"
    end

    #: () -> String
    def inspect
      "#<Enummify::EnumHash[#{@enum_class.name}]: #{to_h.inspect}>"
    end

    #: (Key & Enummify::Enum) -> bool
    def key?(member)
      @present[member.instance_variable_get(:@ordinal)] == 1
    end

    # Return the present keys as a set, which makes key algebra across two maps a single Integer operation.
    #: () -> EnumSet[Key & Enummify::Enum]
    def keys
      cached = @keys
      return cached if cached

      built = EnumSet.send(:new, @enum_class, @present) #: as EnumSet[Key & Enummify::Enum]
      @keys = built
      built
    end

    #: (EnumHash[Key, Value] | Hash[Key, Value]) -> EnumHash[Key, Value]
    def merge(entries)
      duplicate = EnumHash.send(:new, @enum_class) #: as EnumHash[Key, Value]
      duplicate.merge!(self)
      duplicate.merge!(entries)
      duplicate
    end

    #: (EnumHash[Key, Value] | Hash[Key, Value]) -> self
    def merge!(entries)
      # Both sources yield a key and a value, so the iteration is shared rather than branching on the type.
      entries.each do |member, value|
        # A key is always an enum member, which a type member on its own does not carry into the body.
        key = member #: as Key & Enummify::Enum
        self[key] = value
      end
      self
    end

    #: () -> Integer
    def size
      keys.size
    end

    #: () -> Hash[Key, Value]
    def to_h
      result = {} #: Hash[Key, Value]
      each { |member, value| result[member] = value }
      result
    end

    #: () -> String
    def to_s
      inspect
    end

    # Return the values of the present keys, in declaration order of their keys.
    #: () -> Array[Value]
    def values
      result = [] #: Array[Value]
      each { |_member, value| result << value }
      result
    end

    alias each_pair each
    alias has_key? key?
    alias include? key?
    alias length size
    alias member? key?
    alias store []=

    protected

    # Exposed to sibling maps so equality can compare state without widening the public API.
    #: Array[Value?]
    attr_reader :entries

    #: singleton(Enummify::Enum)
    attr_reader :enum_class

    #: Integer
    attr_reader :present

    private

    # The capacity is read once, which is sound because members are declared in the class body and never added later.
    #: (singleton(Enummify::Enum)) -> void
    def initialize(enum_class)
      @enum_class = enum_class
      @entries = Array.new(enum_class.values.length) #: Array[Value?]
      @present = 0 #: Integer
      @keys = nil #: EnumSet[Key & Enummify::Enum]?
    end
  end
end
