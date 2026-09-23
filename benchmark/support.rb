# typed: strict
# frozen_string_literal: true

require 'objspace'
require_relative '../lib/enummify'

# Shared fixtures, timing and reporting for comparing Enummify's containers against Set and Hash.
module EnummifyBenchmark
  # Each round runs for at least this long, which swamps timer resolution without making a full run take minutes.
  ROUND_NANOSECONDS = 25_000_000

  # The fastest round is reported, because garbage collection and the OS only ever add time to a round.
  ROUNDS = 5

  # 62 is the largest enum whose masks are immediate Integers.
  # Larger enums have Bignum masks and are not a performance target, so they are not measured.
  SIZES = [8, 40, 62].freeze

  @harness_nanoseconds = nil #: Float?

  # How one kind of measurement is printed.
  # Lower is better for every kind measured here, so each only names its two directions.
  class Metric
    #: String
    attr_reader :better

    # What each row of a table names.
    #: String
    attr_reader :subject

    #: String
    attr_reader :unit

    #: String
    attr_reader :worse

    #: (unit: String, subject: String, format: String, better: String, worse: String) -> void
    def initialize(unit:, subject:, format:, better:, worse:)
      @unit = unit
      @subject = subject
      @format = format
      @better = better
      @worse = worse
    end

    #: (Numeric) -> String
    def format(value)
      Kernel.format(@format, value)
    end
  end

  BYTES = Metric.new(unit: 'B', subject: 'Container', format: '%d', better: 'smaller', worse: 'larger') #: Metric
  NANOSECONDS = Metric.new(unit: 'ns', subject: 'Operation', format: '%.1f', better: 'faster', worse: 'slower') #: Metric

  # One measurement per row of a stdlib container and of its Enummify counterpart, for one enum size.
  class Table
    #: (stdlib: String, enummify: String, size: Integer, metric: Metric) -> void
    def initialize(stdlib:, enummify:, size:, metric:)
      @stdlib = stdlib
      @enummify = enummify
      @size = size
      @metric = metric
      @rows = [] #: Array[[String, Numeric, Numeric]]
    end

    #: (String, Numeric, Numeric) -> void
    def add(subject, stdlib_value, enummify_value)
      @rows << [subject, stdlib_value, enummify_value]
    end

    # Render as Markdown, so a run can be pasted into the README.
    #: () -> String
    def to_markdown
      lines = [
        "### #{@size} members",
        '',
        "| #{@metric.subject} | #{@stdlib} (#{@metric.unit}) | #{@enummify} (#{@metric.unit}) | #{@enummify} vs. #{@stdlib} |",
        '| --- | ---: | ---: | --- |'
      ]
      @rows.each do |subject, stdlib_value, enummify_value|
        lines << "| #{subject} | #{@metric.format(stdlib_value)} | #{@metric.format(enummify_value)} | " \
                 "#{comparison(stdlib_value, enummify_value)} |"
      end
      lines.join("\n")
    end

    private

    #: (Numeric, Numeric) -> String
    def comparison(stdlib_value, enummify_value)
      if enummify_value == stdlib_value
        'same'
      elsif enummify_value < stdlib_value
        Kernel.format("%.2f× #{@metric.better}", stdlib_value.fdiv(enummify_value))
      else
        Kernel.format("%.2f× #{@metric.worse}", enummify_value.fdiv(stdlib_value))
      end
    end
  end

  # Build an enum with the given number of members, for sizes that are impractical to write out.
  #: (Integer) -> singleton(Enummify::Enum)
  def self.enum_of_size(size)
    Class.new(Enummify::Enum) do
      size.times { |index| const_set(:"MEMBER_#{index}", new) }
    end
  end

  # Return the nanoseconds per call of the block, from the fastest of several rounds, including the harness itself.
  # The number of calls per round is calibrated first, so an operation that walks every member gets the same time
  # budget as one that reads a single bit, and the calibration doubles as warm-up for YJIT.
  #: () { () -> void } -> Float
  def self.gross_nanoseconds_per_call(&)
    GC.start
    calls = 1
    calls *= 2 while nanoseconds_for(calls, &) < ROUND_NANOSECONDS
    fastest = Array.new(ROUNDS) { nanoseconds_for(calls, &) }.min #: as Integer
    fastest.fdiv(calls)
  end

  # The cost of calling a block that does nothing, which every gross timing contains.
  # The first measurement is discarded, because under YJIT it measured about 4 ns higher than every later one, which
  # pushed the cheapest operations below zero.
  #: () -> Float
  def self.harness_nanoseconds
    @harness_nanoseconds ||= begin
      gross_nanoseconds_per_call(&-> {})
      gross_nanoseconds_per_call(&-> {})
    end
  end

  # Measure the bytes owned by each pair of equivalent containers.
  #: (stdlib: String, enummify: String, size: Integer, containers: Hash[String, [Object, Object]]) -> Table
  def self.memory_table(stdlib:, enummify:, size:, containers:)
    table = Table.new(stdlib:, enummify:, size:, metric: BYTES)
    containers.each do |description, (stdlib_container, enummify_container)|
      table.add(description, owned_bytes(stdlib_container), owned_bytes(enummify_container))
    end
    table
  end

  #: (Integer) { () -> void } -> Integer
  def self.nanoseconds_for(calls, &)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
    # A while loop adds less per call than an iterator, which keeps the harness out of the measurement.
    index = 0
    while index < calls
      yield
      index += 1
    end
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond).to_i - started.to_i
  end

  # Return the nanoseconds per call that the block costs beyond the harness.
  # The harness costs more than a single bit test, so leaving it in would make every cheap operation look alike.
  #: () { () -> void } -> Float
  def self.nanoseconds_per_call(&)
    gross_nanoseconds_per_call(&) - harness_nanoseconds
  end

  # Bytes held by a container itself, not counting the members and values it refers to.
  # Members are shared singletons and one enum class is shared by every container, so neither belongs to a container.
  #: (Object) -> Integer
  def self.owned_bytes(container)
    container.instance_variables.sum(ObjectSpace.memsize_of(container)) do |name|
      value = container.instance_variable_get(name)
      case value
      when Enummify::EnumSet then owned_bytes(value)
      when Enummify::Enum, Module then 0
      else ObjectSpace.memsize_of(value)
      end
    end
  end

  # Print the Ruby build and a note on what was measured, then the table built for each enum size.
  #: (String, String) { (Integer) -> Table } -> void
  def self.run(title, note, &)
    puts "## #{title}", '', "`#{RUBY_DESCRIPTION}`", '', note
    SIZES.each { |size| puts '', yield(size).to_markdown }
  end

  # Time each pair of equivalent operations, given as a call on the stdlib container and one on Enummify's.
  #: (stdlib: String, enummify: String, size: Integer, operations: Hash[String, [^() -> void, ^() -> void]]) -> Table
  def self.time_table(stdlib:, enummify:, size:, operations:)
    table = Table.new(stdlib:, enummify:, size:, metric: NANOSECONDS)
    operations.each do |operation, (stdlib_call, enummify_call)|
      table.add(operation, nanoseconds_per_call(&stdlib_call), nanoseconds_per_call(&enummify_call))
    end
    table
  end

  # Describe how timings were taken, including the harness overhead subtracted from each of them.
  #: () -> String
  def self.timing_note
    "Nanoseconds per call, from the fastest of #{ROUNDS} rounds.\n" \
      "Each timing excludes the #{NANOSECONDS.format(harness_nanoseconds)} ns per call that the harness itself costs."
  end
end
