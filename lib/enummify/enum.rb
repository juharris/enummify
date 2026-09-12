# typed: strict
# frozen_string_literal: true

module Enummify
  # A typed set of immutable, named instances with string serialization.
  class Enum
    # Each subclass owns a registry containing only instances of that subclass.
    @members = {} #: Hash[Symbol, Enum]
    @values_by_serialization = {} #: Hash[String, Enum]

    # Register direct constants so only named members belong to the enum.
    #: (Symbol) -> void
    def self.const_added(constant)
      super

      member = validate_member(const_get(constant, false), constant)
      serialized = member.send(:finalize, constant)
      raise ArgumentError, "#{name}::#{constant} is already defined" if @members.key?(constant)
      raise ArgumentError, "Duplicate #{name} value: #{serialized.inspect}" if @values_by_serialization.key?(serialized)

      @members[constant] = member
      @values_by_serialization[serialized] = member
    end

    # Look up a member by its exact serialized string.
    #: (String) -> instance
    def self.deserialize(serialized)
      member = try_deserialize(serialized)
      raise ArgumentError, "Unknown #{name} value: #{serialized.inspect}" unless member

      member
    end

    class << self
      # Restore the canonical member when loading a Marshal stream.
      alias _load deserialize
    end

    # Look up a member, returning nil for an unknown string.
    #: (String) -> instance?
    def self.try_deserialize(serialized)
      serialized = validate_serialized(serialized)

      @values_by_serialization[serialized] #: as instance?
    end

    # Return an immutable snapshot of the members in declaration order.
    #: () -> Array[instance]
    def self.values
      @members.values.freeze #: as Array[instance]
    end

    #: (singleton(Enummify::Enum)) -> void
    def self.inherited(subclass)
      raise TypeError, 'Enum classes cannot be subclassed' unless equal?(Enum)

      super
      subclass.instance_variable_set(:@members, {})
      subclass.instance_variable_set(:@values_by_serialization, {})
    end

    #: (?String?) -> instance
    def self.new(serialized = nil)
      raise TypeError, 'Enum members must belong to a concrete enum class' if equal?(Enum)

      serialized = validate_serialized(serialized) unless serialized.nil?
      super(serialized)
    end

    #: (Object, Symbol) -> Enum
    def self.validate_member(member, constant)
      raise TypeError, "#{name}::#{constant} must be an instance of #{name}" unless member.is_a?(Enum) && member.instance_of?(self)

      member
    end

    # Validate runtime inputs without coercing values from untyped callers.
    #: (Object) -> String
    def self.validate_serialized(serialized)
      raise TypeError, 'Serialized enum values must be Strings' unless serialized.is_a?(String)

      serialized
    end

    private_class_method :const_added, :inherited, :new, :validate_member, :validate_serialized

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
      serialized = @serialized ||= constant.name
      freeze
      serialized
    end

    #: (String?) -> void
    def initialize(serialized)
      # Own the string so freezing a member does not freeze the caller's input.
      @serialized = serialized&.dup&.freeze #: String?
    end
  end
end
