# typed: strict
# frozen_string_literal: true

require_relative 'support'

# Compare the memory that EnumSet and EnumHash hold against Set and Hash with the same contents.
module MemoryBenchmark
  #: (Integer) -> EnummifyBenchmark::Table
  def self.table_for(size)
    enum = EnummifyBenchmark.enum_of_size(size)
    members = enum.values
    empty_hash = {} #: Hash[Enummify::Enum, Integer]
    full_hash = members.to_h { |member| [member, member.ordinal] }

    EnummifyBenchmark.memory_table(
      stdlib: 'stdlib', enummify: 'Enummify', size:,
      containers: {
        'empty set' => [Set.new, Enummify::EnumSet.none(enum)],
        'full set' => [Set.new(members), Enummify::EnumSet.all(enum)],
        # Iterating a set caches its member Array, which a set that is only combined and tested never allocates.
        'full set, once iterated' => [Set.new(members), Enummify::EnumSet.all(enum).tap(&:to_a)],
        'empty map' => [empty_hash, Enummify::EnumHash.from(enum, empty_hash)],
        'full map' => [full_hash, Enummify::EnumHash.from(enum, full_hash)],
        # Reading the keys caches them as a set, until the next write.
        'full map, once its keys are read' => [full_hash, Enummify::EnumHash.from(enum, full_hash).tap(&:keys)]
      }
    )
  end
end

EnummifyBenchmark.run(
  'Memory',
  'Bytes owned by each container, excluding the members and values it refers to, which are shared.'
) { |size| MemoryBenchmark.table_for(size) }
