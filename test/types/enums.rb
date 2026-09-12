# typed: strict
# frozen_string_literal: true

require 'enummify'

module TypeExamples
  class OtherStatus < Enummify::Enum
    Pending = new #: OtherStatus
  end

  class Status < Enummify::Enum
    Pending = new #: Status
    RUNNING = new #: Status
    Succeeded = new('succeeded') #: Status
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
consumer.serialize(TypeExamples::Status::Pending)
consumer.serialize(TypeExamples::Status::RUNNING)
consumer.serialize(TypeExamples::Status::Succeeded)
consumer.serialize(TypeExamples::Status::Pending.clone(freeze: false))
consumer.serialize(TypeExamples::Status::Pending.dup)
consumer.serialize(TypeExamples::Status._load('RUNNING'))
consumer.serialize(consumer.deserialize)
consumer.values.each { |member| consumer.serialize(member) }
member = consumer.try_deserialize
consumer.serialize(member) if member
