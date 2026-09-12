# typed: strict
# frozen_string_literal: true

module Enummify
  # A typed set of immutable, named instances with string serialization.
  class Enum
    #: (String) -> instance
    def self._load(serialized); end

    #: (String) -> instance
    def self.deserialize(serialized); end

    #: (?String?) -> instance
    def self.new(serialized = nil); end

    #: (String) -> instance?
    def self.try_deserialize(serialized); end

    #: () -> Array[instance]
    def self.values; end

    private_class_method :new

    #: (Integer) -> String
    def _dump(_depth); end

    #: (?freeze: bool?) -> self
    def clone(freeze: true); end

    #: () -> self
    def dup; end

    #: () -> String
    def inspect; end

    #: () -> String
    def serialize; end

    #: () -> String
    def to_s; end
  end
end
