# typed: strict
# frozen_string_literal: true

module Enummify
  # A typed set of immutable, named instances with string serialization.
  class Enum
    extend T::Sig

    sig { params(serialized: String).returns(T.attached_class) }
    def self._load(serialized); end

    sig { params(serialized: String).returns(T.attached_class) }
    def self.deserialize(serialized); end

    sig { params(serialized: T.nilable(String)).returns(T.attached_class) }
    def self.new(serialized = nil); end

    sig { params(serialized: String).returns(T.nilable(T.attached_class)) }
    def self.try_deserialize(serialized); end

    sig { returns(T::Array[T.attached_class]) }
    def self.values; end

    private_class_method :new

    sig { params(_depth: Integer).returns(String) }
    def _dump(_depth); end

    sig { params(freeze: T.nilable(T::Boolean)).returns(T.self_type) }
    def clone(freeze: true); end

    sig { returns(T.self_type) }
    def dup; end

    sig { returns(String) }
    def inspect; end

    sig { returns(String) }
    def serialize; end

    sig { returns(String) }
    def to_s; end
  end
end
