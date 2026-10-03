# typed: strict
# frozen_string_literal: true

require_relative 'support'

# Compare EnumSet against Set on the operations that a set of enum members is used for.
module EnumSetBenchmark
  #: (Integer) -> EnummifyBenchmark::Table
  def self.table_for(size)
    enum = EnummifyBenchmark.enum_of_size(size)
    members = enum.values
    probe = members.fetch(size - 1)
    # Three overlapping groups, so union, intersection and difference each keep some members and drop others.
    evens = members.select { |member| member.ordinal.even? }
    low = members.first(size / 2)
    high = members.last(size / 2)

    set_all = Set.new(members)
    set_evens = Set.new(evens)
    set_low = Set.new(low)
    set_high = Set.new(high)
    enum_set_all = Enummify::EnumSet.from(enum, members)
    enum_set_evens = Enummify::EnumSet.from(enum, evens)
    enum_set_low = Enummify::EnumSet.from(enum, low)
    enum_set_high = Enummify::EnumSet.from(enum, high)

    EnummifyBenchmark.time_table(
      stdlib: 'Set', enummify: 'EnumSet', size:,
      operations: {
        'include?' => [-> { set_all.include?(probe) }, -> { enum_set_all.include?(probe) }],
        'union' => [-> { set_evens | set_low }, -> { enum_set_evens | enum_set_low }],
        'intersection' => [-> { set_evens & set_low }, -> { enum_set_evens & enum_set_low }],
        'difference' => [-> { set_evens - set_low }, -> { enum_set_evens - enum_set_low }],
        'chained `(a \\| b) & c`' => [-> { (set_evens | set_low) & set_high },
                                      -> { (enum_set_evens | enum_set_low) & enum_set_high }],
        'subset?' => [-> { set_low.subset?(set_all) }, -> { enum_set_low.subset?(enum_set_all) }],
        'size' => [-> { set_all.size }, -> { enum_set_all.size }],
        'size of a new union' => [-> { (set_evens | set_low).size }, -> { (enum_set_evens | enum_set_low).size }],
        'build from an Array' => [-> { Set.new(members) }, -> { Enummify::EnumSet.from(enum, members) }],
        # The blocks deliberately do nothing, so iterating is all that is timed.
        # rubocop:disable Lint/Void
        'each' => [-> { set_all.each { |member| member } }, -> { enum_set_all.each { |member| member } }],
        'each of a new union' => [-> { (set_evens | set_low).each { |member| member } },
                                  -> { (enum_set_evens | enum_set_low).each { |member| member } }],
        # rubocop:enable Lint/Void
        'map' => [-> { set_all.map { |member| member } }, -> { enum_set_all.map { |member| member } }]
      }
    )
  end
end

EnummifyBenchmark.run('EnumSet vs. Set', EnummifyBenchmark.timing_note) { |size| EnumSetBenchmark.table_for(size) }
