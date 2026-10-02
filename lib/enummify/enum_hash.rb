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
    # The type of NO_DEFAULT, which lets fetch narrow an omitted default away from a given one.
    class NoDefault; end

    # The default for an omitted fetch default, which is distinct from every value, including nil.
    NO_DEFAULT = NoDefault.new.freeze #: NoDefault

    private_constant :NO_DEFAULT, :NoDefault

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
    #: [K < Enummify::Enum, V] (Class[K] & singleton(Enummify::Enum), Hash[K, V]) -> EnumHash[K, V]
    def self.from(enum_class, entries)
      result = new(enum_class) #: EnumHash[K, V]
      result.merge!(entries)
      result
    end

    # Build a map from key and value pairs, which infers both types even when they are written at the call site.
    #: [K < Enummify::Enum, V] (Class[K] & singleton(Enummify::Enum), *[K & Enummify::Enum, V]) -> EnumHash[K, V]
    def self.of(enum_class, *entries)
      result = new(enum_class) #: EnumHash[K, V]
      entries.each { |member, value| result[member] = value }
      result
    end

    #: (Key & Enummify::Enum) -> Value?
    def [](member)
      @entries[member.ordinal]
    end

    # The slot is written first, so a write to a frozen map raises from its frozen slots before anything changes.
    # Writing the presence mask first would raise from the map itself, but measured 6 ns slower per overwrite in the
    # interpreter.
    #: (Key & Enummify::Enum, Value) -> void
    def []=(member, value)
      @entries[member.ordinal] = value
      bit = member.bit
      # Overwriting a present key changes neither the key set nor the size, so both stay cached.
      return if @present & bit != 0

      @present |= bit
      @size += 1
      @keys = nil
    end

    # Equality accepts any object, so unlike the keyed operations it checks what it was given.
    #: (untyped) -> bool
    def ==(other)
      same_enum_and_keys?(other) && other.entries == @entries
    end

    # Remove every entry, keeping the capacity already allocated for this enum.
    #: () -> self
    def clear
      @entries = Array.new(@entries.length)
      @present = 0
      @size = 0
      @keys = nil
      self
    end

    # Remove an entry and return the value it held, or nil when the key was absent.
    #: (Key & Enummify::Enum) -> Value?
    def delete(member)
      ordinal = member.ordinal
      return nil unless @present[ordinal] == 1

      value = @entries[ordinal]
      @entries[ordinal] = nil
      # The key is present, so subtracting its bit clears it.
      # Subtracting measured faster than ^ in the interpreter, because subtraction has a specialized instruction and ^
      # is an ordinary method call.
      @present -= member.bit
      @size -= 1
      @keys = nil
      value
    end

    # Yield each present key and its value in declaration order.
    # A while loop over the cached key array measured faster than a block inside the key array's each, because it
    # skips a block call per entry.
    #: () { (Key & Enummify::Enum, Value) -> void } -> self
    def each(&)
      members = keys.to_a
      entries = @entries
      index = 0
      while index < members.length
        member = members[index] #: as !nil
        # Only present keys are yielded, so the slot holds a value that was written rather than an empty slot.
        value = entries[member.ordinal] #: as Value
        yield(member, value)
        index += 1
      end
      self
    end

    #: () -> bool
    def empty?
      @present.zero?
    end

    # Like Hash#eql?, this compares values with eql? rather than ==, so a map holding 1 is not eql? to one holding 1.0.
    #: (untyped) -> bool
    def eql?(other)
      same_enum_and_keys?(other) && other.entries.eql?(@entries)
    end

    # Return the value for a member.
    # When the key is absent, return the block's result or else the default, and raise KeyError when given neither.
    # As in Hash#fetch, a block takes precedence over a default.
    # Hash#fetch also warns when given both, which the exported RBI's overloads reject statically instead.
    # The optional default measured about 5 ns slower per call in the interpreter whether it defaulted to a constant
    # or to nil, so the cost is the optional parameter itself, and under YJIT it measured within noise.
    #: [D] (Key & Enummify::Enum, ?(D | NoDefault)) ?{ (Key & Enummify::Enum) -> D } -> (Value | D)
    def fetch(member, default = NO_DEFAULT, &block)
      ordinal = member.ordinal
      if @present[ordinal] == 1
        # A present key was written, so the slot holds a value rather than an empty slot.
        value = @entries[ordinal] #: as Value
        return value
      end
      return block.call(member) if block

      # Matching on the class rather than comparing with NO_DEFAULT narrows the default to its type parameter.
      case default
      when NoDefault then raise KeyError, "key not found: #{member.inspect}"
      else default
      end
    end

    # Freeze the map, first caching its keys and freezing its slots.
    #: () -> self
    def freeze
      prepare_to_freeze
      super
    end

    # Maps that are eql? hash alike, so a map can be a Hash key.
    # Like a Hash, a map that changes while it is a key is no longer found under it.
    #: () -> Integer
    def hash
      [@enum_class, @present, @entries].hash
    end

    #: () -> String
    def inspect
      "#<Enummify::EnumHash[#{@enum_class.name}]: #{to_h.inspect}>"
    end

    # Masking by the member's bit rather than indexing by ordinal matches EnumSet#include?, for the same reason.
    #: (Key & Enummify::Enum) -> bool
    def key?(member)
      @present & member.bit != 0
    end

    # Return the present keys as a set, which makes key algebra across two maps a single Integer operation.
    #: () -> EnumSet[Key & Enummify::Enum]
    def keys
      cached = @keys
      return cached if cached

      built = EnumSet.new(@enum_class, @present)
      # Marshal.load with freeze: true freezes a map without calling freeze, so such a map builds its keys every time.
      @keys = built unless frozen?
      built
    end

    # A copy starts with this map's slots, size and keys, so only the other entries are stored.
    #: (EnumHash[Key, Value] | Hash[Key, Value]) -> EnumHash[Key, Value]
    def merge(entries)
      dup.merge!(entries)
    end

    #: (EnumHash[Key, Value] | Hash[Key, Value]) -> self
    def merge!(entries)
      # Another map's slots line up with this map's, so they are copied directly rather than stored entry by entry.
      if entries.is_a?(EnumHash)
        overlay(entries)
      else
        entries.each do |member, value|
          # A key is always an enum member, which a type member on its own does not carry into the body.
          key = member #: as Key & Enummify::Enum
          self[key] = value
        end
      end
      self
    end

    # The number of present keys, which is counted as keys are added and removed so that reading it walks nothing.
    #: Integer
    attr_reader :size

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

    # new is public only for the reason given at EnumSet#initialize, and is not meant for use outside Enummify.
    # The capacity is read once, which is sound because members are declared in the class body and never added later.
    #: (singleton(Enummify::Enum)) -> void
    def initialize(enum_class)
      @enum_class = enum_class
      @entries = Array.new(enum_class.values.length) #: Array[Value?]
      @present = 0 #: Integer
      @size = 0 #: Integer
      @keys = nil #: EnumSet[Key & Enummify::Enum]?
    end

    # Kernel#clone freezes the copy without calling freeze, so a copy that will be frozen prepares for it here.
    #: (EnumHash[Key, Value], ?freeze: bool?) -> void
    def initialize_clone(source, freeze: nil)
      super
      prepare_to_freeze if freeze.nil? ? source.frozen? : freeze
    end

    # A copy gets its own slots, so writing to it leaves the source alone.
    #: (EnumHash[Key, Value]) -> void
    def initialize_copy(source)
      super
      @entries = @entries.dup
    end

    # Copy another map's present slots over this map's, then take the union of both key sets.
    # A while loop over the other map's cached key array measured faster than storing its entries one by one.
    # Counting the added keys while copying replaced counting the bits of a newly built key set.
    # It measured about a quarter faster for 8 members, and for larger enums a tenth faster under YJIT but up to 5%
    # slower in the interpreter.
    # The slots are written first, so a frozen map raises from its frozen slots before its keys change.
    #: (EnumHash[Key, Value]) -> void
    def overlay(other)
      entries = @entries
      other_entries = other.entries
      present = @present
      size = @size
      members = other.keys.to_a
      index = 0
      while index < members.length
        member = members[index] #: as !nil
        ordinal = member.ordinal
        entries[ordinal] = other_entries[ordinal]
        size += 1 unless present[ordinal] == 1
        index += 1
      end
      return if size == @size

      @present = present | other.present
      @size = size
      @keys = nil
    end

    # Cache the keys and freeze the slots, which a frozen map could no longer do.
    # A write stores its value in a slot before it changes the map itself, so frozen slots are what make a write to a
    # frozen map raise before anything changes.
    #: () -> void
    def prepare_to_freeze
      keys
      @entries.freeze
    end

    # Check that another object is a map over the same enum with the same keys, which both == and eql? require.
    #: (untyped) -> bool
    def same_enum_and_keys?(other)
      return false unless other.is_a?(EnumHash)

      other.enum_class.equal?(@enum_class) && other.present == @present
    end
  end
end
