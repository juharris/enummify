# typed: strict
# frozen_string_literal: true

module Enummify
  # A typed set of immutable, named instances with string serialization.
  class Enum
    @serialized_to_value = {} #: Hash[String, Enum]
    @values = nil #: Array[Enum]?

    # Register direct constants so only named members belong to the enum.
    #: (Symbol) -> void
    def self.const_added(constant)
      super

      member = const_get(constant, false) #: as Enum
      serialized = member.send(:finalize, constant)
      existing = @serialized_to_value[serialized]
      if existing
        raise ArgumentError, "Duplicate serialized value for #{name}: #{serialized.inspect} is already taken by #{existing.inspect}"
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
    #: (Symbol) -> String
    def finalize(constant)
      @serialized ||= constant.name
      freeze
      @serialized
    end

    #: (?String?) -> void
    def initialize(serialized = nil)
      @serialized = serialized&.dup&.freeze #: String?
    end
  end
end
