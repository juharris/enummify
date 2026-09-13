# typed: strict
# frozen_string_literal: true

# Every call must remain a type error, even when the serialized strings coincide.
consumer = TypeExamples::Consumer.new
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
