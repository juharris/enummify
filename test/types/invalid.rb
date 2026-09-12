# typed: strict
# frozen_string_literal: true

# Every call must remain a type error, even when the serialized strings coincide.
consumer = TypeExamples::Consumer.new
# expect-type-error: 7002
consumer.serialize('Pending')
# expect-type-error: 7002
consumer.serialize(TypeExamples::OtherStatus::Pending)
# expect-type-error: 7002
consumer.serialize(TypeExamples::OtherStatus.deserialize('Pending'))
# expect-type-error: 7002
consumer.serialize(TypeExamples::OtherStatus.values.fetch(0))
# expect-type-error: 7002
TypeExamples::Status.deserialize(:Pending)
# expect-type-error: 7002
TypeExamples::Status.try_deserialize(:Pending)
# expect-type-error: 7002
consumer.serialize(TypeExamples::Status.try_deserialize('Pending'))
# expect-type-error: 5002
consumer.serialize(TypeExamples::Status::Running)
# expect-type-error: 7031
TypeExamples::Status.new

class InvalidStatus < Enummify::Enum
  # expect-type-error: 7002
  Pending = new(:pending) #: InvalidStatus
end
