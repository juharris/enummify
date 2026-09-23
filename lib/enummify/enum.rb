# typed: strict
# frozen_string_literal: true

module Enummify
  # A typed set of immutable, named instances with string serialization.
  class Enum
    @serialized_to_value = {} #: Hash[String, Enum]
    @values = nil #: Array[Enum]?

    # Register each constant as a member, which assumes every constant in the class body is one.
    # Groupings such as sets belong outside the enum class.
    #: (Symbol) -> void
    def self.const_added(constant)
      super

      member = const_get(constant, false)
      # The registry size is the member's declaration index, which EnumSet and EnumHash rely on.
      serialized = member.send(:finalize, constant, @serialized_to_value.size) #: as String
      if @serialized_to_value.key?(serialized)
        raise ArgumentError, "Duplicate serialized value for #{name}: #{serialized.inspect} is already used"
      end

      @serialized_to_value[serialized] = member
    end

    # Look up a member by its exact serialized string.
    #: (String) -> instance
    def self.deserialize(serialized)
      @serialized_to_value[serialized] || raise(ArgumentError, "Unknown #{name} value: #{serialized.inspect}") #: as instance
    end

    class << self
      # Restore the canonical member when loading a Marshal stream.
      alias _load deserialize
    end

    # Build a set of this enum's members, backed by a bitmask.
    # The attached class cannot appear in a parameter, so the member type is taken from the arguments instead.
    # Mixing enums therefore yields a set of the wrong member type, which is rejected wherever that set is used.
    # At least one member is required, because an empty set has nothing to take the member type from.
    # Use EnumSet.none for that.
    #: [M] (M & Enum, *(M & Enum)) -> EnumSet[M]
    def self.set(member, *members)
      # A set is unordered, so the first member goes on the end of the rest rather than paying to shift them along.
      EnumSet.from(self, members.push(member)) #: as EnumSet[M]
    end

    # Look up a member, returning nil for an unknown string.
    #: (String) -> instance?
    def self.try_deserialize(serialized)
      @serialized_to_value[serialized] #: as instance?
    end

    # Return the members.
    #: () -> Array[instance]
    def self.values
      (@values ||= @serialized_to_value.values.freeze) #: as Array[instance]
    end

    # Give each enum class its own registry.
    #: (singleton(Enummify::Enum)) -> void
    def self.inherited(subclass)
      super
      subclass.instance_variable_set(:@serialized_to_value, {})
    end

    private_class_method :const_added, :inherited

    # Store only the serialized string so Marshal loading uses the registered member.
    #: (Integer) -> String
    def _dump(_depth)
      serialize
    end

    # The member's bit in EnumSet and EnumHash masks, which is 1 shifted left by the ordinal.
    # It is public only so those classes can read it without a slower private lookup, and is not meant for use
    # outside Enummify.
    # It is computed once because shifting at every use measured slower, both when building a mask and when testing
    # one that is an immediate Integer.
    # Like the ordinal, it changes when members are inserted or reordered.
    #: Integer
    attr_reader :bit

    # Enum members are immutable singletons, including copies requested as unfrozen.
    # rubocop:disable Lint/UnusedMethodArgument
    #: (?freeze: bool?) -> self
    def clone(freeze: true)
      self
    end
    # rubocop:enable Lint/UnusedMethodArgument

    #: () -> self
    def dup
      self
    end

    #: () -> String
    def inspect
      "#<#{self.class.name}: #{serialize.inspect}>"
    end

    # The member's 0-based position in declaration order, which EnumHash uses as its slot.
    # It is public only so EnumSet and EnumHash can read it without a slower private lookup, and is not meant for use
    # outside Enummify.
    # It changes when members are inserted or reordered, so persist serialize rather than this.
    #: Integer
    attr_reader :ordinal

    #: () -> String
    def serialize
      @serialized || raise(ArgumentError, 'Enum members must be assigned to a constant before serialization')
    end

    #: () -> String
    def to_s
      serialize
    end

    private

    # The constant name is only available after construction has returned.
    # The ordinal and bit must be assigned here rather than by the caller because this method freezes the member.
    # Assigning conditionally leaves an already registered member untouched, so aliasing one reaches the caller's
    # duplicate check rather than failing to write to a frozen member.
    #: (Symbol, Integer) -> String
    def finalize(constant, ordinal)
      unless frozen?
        @ordinal = ordinal
        @bit = 1 << ordinal
      end
      @serialized ||= constant.name
      freeze
      @serialized
    end

    #: (?String?) -> void
    def initialize(serialized = nil)
      # Declaration order and its bit, assigned during registration.
      # They start as Integers rather than nil so the readers need no check, because every EnumSet and EnumHash
      # operation reads one of them.
      @bit = 0 #: Integer
      @ordinal = -1 #: Integer
      @serialized = serialized&.dup&.freeze #: String?
    end
  end
end
