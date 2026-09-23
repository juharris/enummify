# typed: strict
# frozen_string_literal: true

# Every call must remain a type error, even when the serialized strings coincide.
consumer = TypeExamples::Consumer.new
# expect-type-error: 7002
consumer.labels.fetch('PENDING')
# expect-type-error: 7002
consumer.labels.fetch(TypeExamples::OtherStatus::PENDING)
# expect-type-error: 7002
consumer.serialize('PENDING')
# expect-type-error: 7002
consumer.serialize(TypeExamples::OtherStatus::PENDING)
# expect-type-error: 7002
consumer.serialize(TypeExamples::OtherStatus.deserialize('PENDING'))
# expect-type-error: 7002
consumer.serialize(TypeExamples::OtherStatus.values.fetch(0))
# expect-type-error: 7002
TypeExamples::Status.deserialize(:PENDING)
# expect-type-error: 7002
TypeExamples::Status.try_deserialize(:PENDING)
# expect-type-error: 7002
consumer.serialize(TypeExamples::Status.try_deserialize('PENDING'))
# expect-type-error: 5002
consumer.serialize(TypeExamples::Status::UNKNOWN)

class InvalidStatus < Enummify::Enum
  # expect-type-error: 7002
  PENDING = new(:pending) #: InvalidStatus
end

# A set and a map are scoped to one enum, which the type checker enforces in place of a runtime check.
in_flight = consumer.in_flight
other_set = TypeExamples::OtherStatus.set(TypeExamples::OtherStatus::PENDING)
counts = consumer.counts

# expect-type-error: 7002
consumer.serialize_all(other_set)
# expect-type-error: 7002
in_flight.include?(TypeExamples::OtherStatus::PENDING)
# expect-type-error: 7002
in_flight.add(TypeExamples::OtherStatus::PENDING)
# expect-type-error: 7002
in_flight.delete(TypeExamples::OtherStatus::PENDING)
# expect-type-error: 7002
in_flight | other_set
# expect-type-error: 7002
in_flight & other_set
# expect-type-error: 7002
in_flight.subset?(other_set)
# expect-type-error: 7002
counts[TypeExamples::OtherStatus::PENDING]
# expect-type-error: 7002
counts[TypeExamples::OtherStatus::PENDING] = 1
# expect-type-error: 7002
counts[TypeExamples::Status::PENDING] = 'one'
# expect-type-error: 7002
counts.key?(TypeExamples::OtherStatus::PENDING)
# expect-type-error: 7002
counts.delete(TypeExamples::OtherStatus::PENDING)
# expect-type-error: 7002
counts.fetch(TypeExamples::OtherStatus::PENDING)

# A factory takes its member type from its arguments, so a foreign member widens the set or map it builds rather
# than being rejected where it is written. The mistyped result is then rejected at its first use.
# expect-type-error: 7002
consumer.serialize_all(Enummify::EnumSet.of(TypeExamples::Status, TypeExamples::OtherStatus::PENDING))
# expect-type-error: 7002
consumer.serialize_all(Enummify::EnumSet.from(TypeExamples::Status, [TypeExamples::OtherStatus::PENDING]))
# expect-type-error: 7002
consumer.serialize_all(TypeExamples::Status.set(TypeExamples::OtherStatus::PENDING))
# expect-type-error: 7002
TypeExamples::Status.set(TypeExamples::Status::PENDING, 'RUNNING')
wrong_values = Enummify::EnumHash.of(TypeExamples::Status, [TypeExamples::Status::PENDING, 'one'])
# expect-type-error: 7003
wrong_values.fetch(TypeExamples::Status::PENDING).abs
