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

  # These signatures verify that consumer code preserves the concrete enum type.
  class Consumer
    #: () -> Enummify::EnumHash[Status, Integer]
    def counts
      Enummify::EnumHash.of(Status, [Status::PENDING, 1], [Status::RUNNING, 2])
    end

    #: () -> Status
    def deserialize
      Status.deserialize('RUNNING')
    end

    #: () -> Enummify::EnumSet[Status]
    def in_flight
      Status.set(Status::PENDING, Status::RUNNING)
    end

    #: () -> Hash[Status, String]
    def labels
      { Status::PENDING => 'Waiting', Status::RUNNING => 'Active', Status::SUCCEEDED => 'Done' }
    end

    #: (Status) -> String
    def serialize(status)
      status.serialize
    end

    #: (Enummify::EnumSet[Status]) -> Array[String]
    def serialize_all(statuses)
      statuses.map(&:serialize)
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
consumer.labels.fetch(TypeExamples::Status.deserialize('PENDING'))
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

# The set and map preserve the member type through every operation a consumer is expected to chain.
in_flight = consumer.in_flight
finished = ~in_flight
consumer.serialize_all(in_flight | finished)
consumer.serialize_all(in_flight & TypeExamples::Status.set(TypeExamples::Status::PENDING))
consumer.serialize_all(in_flight - finished)
consumer.serialize_all(in_flight ^ finished)
consumer.serialize_all(in_flight.add(TypeExamples::Status::SUCCEEDED))
consumer.serialize_all(in_flight.delete(TypeExamples::Status::PENDING))
consumer.serialize_all(Enummify::EnumSet.all(TypeExamples::Status))
consumer.serialize_all(Enummify::EnumSet.none(TypeExamples::Status))
consumer.serialize_all(Enummify::EnumSet.of(TypeExamples::Status, TypeExamples::Status::RUNNING))
consumer.serialize_all(Enummify::EnumSet.from(TypeExamples::Status, TypeExamples::Status.values))
in_flight.each { |status| consumer.serialize(status) }
in_flight.include?(TypeExamples::Status::PENDING)
in_flight.subset?(finished)

counts = consumer.counts
counts[TypeExamples::Status::SUCCEEDED] = 3
counts.fetch(TypeExamples::Status::PENDING)
counts.key?(TypeExamples::Status::RUNNING)
counts.delete(TypeExamples::Status::RUNNING)
counts.each do |status, count|
  consumer.serialize(status)
  count.abs
end
consumer.serialize_all(counts.keys)
counts.to_h.each_key { |status| consumer.serialize(status) }
counts.values.each(&:abs)
consumer.serialize_all(consumer.counts.keys & counts.keys)
