# typed: strict
# frozen_string_literal: true

require 'enummify'

module TypeExamples
  class OtherStatus < Enummify::Enum
    PENDING = new #: OtherStatus
  end

  class Status < Enummify::Enum
    PENDING = new #: Status
    RUNNING = new #: Status
    SUCCEEDED = new('succeeded') #: Status
  end

  # These signatures verify that inherited methods preserve the concrete enum type.
  class Consumer
    #: () -> Status
    def deserialize
      Status.deserialize('RUNNING')
    end

    #: (Status) -> String
    def serialize(status)
      status.serialize
    end

    #: () -> Status?
    def try_deserialize
      Status.try_deserialize('missing')
    end

    #: () -> Array[Status]
    def values
      Status.values
    end
  end
end

consumer = TypeExamples::Consumer.new
consumer.serialize(TypeExamples::Status::PENDING)
consumer.serialize(TypeExamples::Status::RUNNING)
consumer.serialize(TypeExamples::Status::SUCCEEDED)
consumer.serialize(TypeExamples::Status::PENDING.clone(freeze: false))
consumer.serialize(TypeExamples::Status::PENDING.dup)
consumer.serialize(TypeExamples::Status._load('RUNNING'))
consumer.serialize(consumer.deserialize)
consumer.values.each { |member| consumer.serialize(member) }
member = consumer.try_deserialize
consumer.serialize(member) if member
