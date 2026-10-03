# typed: strict
# frozen_string_literal: true

require_relative 'support'

# Compare EnumHash against Hash on the operations that a map keyed by enum members is used for.
module EnumHashBenchmark
  #: (Integer) -> EnummifyBenchmark::Table
  def self.table_for(size)
    enum = EnummifyBenchmark.enum_of_size(size)
    members = enum.values
    probe = members.fetch(size - 1)
    empty_hash = {} #: Hash[Enummify::Enum, Integer]
    # Two overlapping key sets, so intersecting them keeps some keys and drops others.
    hash_all = members.to_h { |member| [member, member.ordinal] }
    hash_evens = hash_all.select { |member, _ordinal| member.ordinal.even? }
    hash_low = hash_all.select { |member, _ordinal| member.ordinal < size / 2 }
    enum_hash_all = Enummify::EnumHash.from(enum, hash_all)
    enum_hash_evens = Enummify::EnumHash.from(enum, hash_evens)
    enum_hash_low = Enummify::EnumHash.from(enum, hash_low)

    EnummifyBenchmark.time_table(
      stdlib: 'Hash', enummify: 'EnumHash', size:,
      operations: {
        '[]' => [-> { hash_all[probe] }, -> { enum_hash_all[probe] }],
        '[]=' => [-> { hash_all[probe] = 1 }, -> { enum_hash_all[probe] = 1 }],
        'key?' => [-> { hash_all.key?(probe) }, -> { enum_hash_all.key?(probe) }],
        'fetch' => [-> { hash_all.fetch(probe) }, -> { enum_hash_all.fetch(probe) }],
        'delete, then store again' => [
          lambda do
            hash_all.delete(probe)
            hash_all[probe] = 1
          end,
          lambda do
            enum_hash_all.delete(probe)
            enum_hash_all[probe] = 1
          end
        ],
        'size' => [-> { hash_all.size }, -> { enum_hash_all.size }],
        # Overwriting a present key keeps the key count and the cached key set, so the size is read, not recounted.
        'size after a store' => [
          lambda do
            hash_all[probe] = 1
            hash_all.size
          end,
          lambda do
            enum_hash_all[probe] = 1
            enum_hash_all.size
          end
        ],
        # The blocks deliberately do nothing, so iterating is all that is timed.
        # Taking the key and value as two parameters stops Hash#each from packing each pair into an Array.
        # rubocop:disable Lint/Void
        'each' => [-> { hash_all.each { |_member, ordinal| ordinal } },
                   -> { enum_hash_all.each { |_member, ordinal| ordinal } }],
        # rubocop:enable Lint/Void
        'keys & keys' => [-> { hash_evens.keys & hash_low.keys }, -> { enum_hash_evens.keys & enum_hash_low.keys }],
        'merge' => [-> { hash_evens.merge(hash_low) }, -> { enum_hash_evens.merge(enum_hash_low) }],
        'build by storing every member' => [
          lambda do
            built = empty_hash.dup
            members.each { |member| built[member] = member.ordinal }
          end,
          lambda do
            built = Enummify::EnumHash.from(enum, empty_hash)
            members.each { |member| built[member] = member.ordinal }
          end
        ]
      }
    )
  end
end

EnummifyBenchmark.run('EnumHash vs. Hash', EnummifyBenchmark.timing_note) { |size| EnumHashBenchmark.table_for(size) }
