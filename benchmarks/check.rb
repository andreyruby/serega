# frozen_string_literal: true

# Checks each benchmark case by the instructions and the allocated objects of
# one call: Serega must run at most 2% more instructions than the fastest
# other gem, at most as many as the hand-written Hash with some more by case,
# and allocate at most a few objects more than the hand-written Hash. Prints a
# table of the counts, adds it to the GitHub job summary on CI, and exits with
# 1 when a case fails.
#
# Valgrind's callgrind counts the instructions, thus the counts are the same
# on a busy machine and between runs. Run it with `rake benchmarks:check`,
# which builds benchmarks/callgrind.c and runs this script under callgrind.

require_relative "support"
require "fiddle"

module BenchmarkCheck
  # The fastest other gem by case and format, see README.md
  RIVALS = {
    ["single", :json] => "oj_serializers",
    ["single", :hash] => "oj_serializers",
    ["collection", :json] => "panko_serializer",
    ["collection", :hash] => "oj_serializers",
    ["relations", :json] => "panko_serializer",
    ["relations", :hash] => "oj_serializers",
    ["only", :json] => "panko_serializer",
    ["only", :hash] => "panko_serializer",
    ["except", :json] => "panko_serializer",
    ["except", :hash] => "panko_serializer"
  }.freeze

  # Calls of each serializer per round, by case. One post takes few
  # instructions, thus more calls keep the cost of the client requests out of
  # the count.
  CALLS = {"single" => 100, "collection" => 5, "relations" => 5, "only" => 5, "except" => 5}.freeze

  # Rounds of each serializer per case. The median drops a round that
  # differs, such as the first round of one post.
  ROUNDS = 3

  # How many more instructions than the hand-written Hash Serega may run, by
  # case
  MAX_PLAIN_RUBY_RATIOS = {
    "single" => 1.1, "collection" => 1.02, "relations" => 1.0, "only" => 1.0, "except" => 1.0
  }.freeze

  # How many more instructions than the fastest other gem Serega may run
  MAX_RIVAL_RATIO = 1.02

  # How many more objects than the hand-written Hash Serega may allocate, by
  # case: the run and its source groups with relations
  MAX_EXTRA_OBJECTS = {"single" => 0, "collection" => 1, "relations" => 22, "only" => 22, "except" => 22}.freeze

  # Columns of the table, and whether each is right-aligned
  COLUMNS = {
    "Case" => false, "Rival" => false, "Serega" => true, "Rival instructions" => true, "Hand-written" => true,
    "Serega/Rival" => true, "Serega/Hand-written" => true, "Objects" => true, "Result" => false
  }.freeze

  # Instructions and allocated objects of one call of a case
  Result = Struct.new(
    :name, :output_format, :rival, :serega, :rival_instructions, :plain_ruby, :serega_objects, :plain_ruby_objects
  ) do
    def max_plain_ruby_ratio
      MAX_PLAIN_RUBY_RATIOS.fetch(name)
    end

    def max_extra_objects
      MAX_EXTRA_OBJECTS.fetch(name)
    end

    def label
      "#{name} #{output_format}"
    end

    def rival_ratio
      serega / rival_instructions
    end

    def plain_ruby_ratio
      serega / plain_ruby
    end

    def extra_objects
      serega_objects - plain_ruby_objects
    end

    def lost?
      rival_ratio > MAX_RIVAL_RATIO
    end

    def slowed_down?
      plain_ruby_ratio > max_plain_ruby_ratio
    end

    def over_allocated?
      extra_objects > max_extra_objects
    end

    def passed?
      !lost? && !slowed_down? && !over_allocated?
    end

    # Short reasons for the Result column
    def result
      return "ok" if passed?

      reasons = []
      reasons << "lost to #{rival}" if lost?
      reasons << "over #{max_plain_ruby_ratio}x the hand-written" if slowed_down?
      reasons << "over #{max_extra_objects} more objects" if over_allocated?
      "FAILED: #{reasons.join(", ")}"
    end

    # @return [Array<String>] Why the case fails, empty when it passes
    def failures
      failures = []
      if lost?
        failures << format("Serega runs %.3fx the instructions of %s, the limit is %.2fx", rival_ratio, rival, MAX_RIVAL_RATIO)
      end
      if slowed_down?
        failures << format(
          "Serega runs %.3fx the instructions of the hand-written Hash, the limit is %.2fx", plain_ruby_ratio, max_plain_ruby_ratio
        )
      end
      if over_allocated?
        failures << "Serega allocates #{extra_objects} more objects than the hand-written Hash, the limit is #{max_extra_objects}"
      end
      failures
    end
  end

  # Counts the instructions of a block with the client requests of
  # benchmarks/callgrind.c, which `rake benchmarks:check` builds. Callgrind
  # writes the count of each block to a new dump file next to its out file.
  module Callgrind
    class << self
      # @return [Boolean] Whether the script runs under Valgrind
      def available?
        return false unless File.exist?(library_path)

        functions.fetch(:on_valgrind).call.positive?
      end

      # @return [Integer] The instructions of the block
      def count
        functions.fetch(:start).call
        yield
        functions.fetch(:stop).call
        @dumps = (@dumps || 0) + 1
        File.read("#{ENV.fetch("CALLGRIND_OUT_FILE")}.#{@dumps}")[/^(?:totals|summary): (\d+)/, 1].to_i
      end

      private

      def library_path
        ENV.fetch("CALLGRIND_LIBRARY", "")
      end

      def functions
        @functions ||= begin
          library = Fiddle.dlopen(library_path)
          {
            on_valgrind: Fiddle::Function.new(library["serega_on_valgrind"], [], Fiddle::TYPE_INT),
            start: Fiddle::Function.new(library["serega_start"], [], Fiddle::TYPE_VOID),
            stop: Fiddle::Function.new(library["serega_stop"], [], Fiddle::TYPE_VOID)
          }
        end
      end
    end
  end

  class << self
    # Checks every case, prints the table and the reasons of the failed cases,
    # and returns whether all cases passed. On GitHub Actions, adds the table
    # and the reasons to the job summary as Markdown, and reports each failed
    # case as one error annotation, as GitHub shows 10 annotations per step.
    #
    # @return [Boolean] Whether Serega passed every case
    def call
      abort "benchmarks/check.rb counts instructions under Valgrind, run it with `rake benchmarks:check`" unless Callgrind.available?

      results = RIVALS.map { |(name, format), rival| check(name, format, rival) }
      rows = rows(results)
      failed = results.reject(&:passed?)
      failures = failed.map { |result| "#{result.label}: #{result.failures.join("; ")}" }
      puts RUBY_DESCRIPTION, "", text_table(rows)
      puts "", "#{failed.size} of #{results.size} cases failed:", *failures.map { |failure| "- #{failure}" } unless failed.empty?

      report_on_github(rows, failures)
      failed.empty?
    end

    private

    def check(name, format, rival)
      reports = BenchmarkCases.public_send(name).fetch(format)
      BenchmarkCases.check(format, reports)
      serega, rival_serializer, plain_ruby = reports.values_at("serega", rival, "plain ruby")
      calls = CALLS.fetch(name)

      Result.new(
        name, format, rival,
        instructions(serega, calls), instructions(rival_serializer, calls), instructions(plain_ruby, calls),
        objects(serega), objects(plain_ruby)
      )
    end

    # Median instructions of one call. GC runs before each round and not
    # during it, as the allocated objects stand for its cost.
    def instructions(serializer, calls)
      serializer.call

      counts = Array.new(ROUNDS) do
        GC.start
        GC.disable
        Callgrind.count { calls.times { serializer.call } }.fdiv(calls)
      ensure
        GC.enable
      end

      counts.sort[ROUNDS / 2]
    end

    # Objects allocated by one call
    def objects(serializer)
      GC.disable
      before = GC.stat(:total_allocated_objects)
      serializer.call
      GC.stat(:total_allocated_objects) - before
    ensure
      GC.enable
    end

    def rows(results)
      results.map do |result|
        [
          result.label, result.rival,
          instructions_count(result.serega), instructions_count(result.rival_instructions), instructions_count(result.plain_ruby),
          ratio(result.rival_ratio), ratio(result.plain_ruby_ratio),
          "#{number(result.serega_objects)} / #{number(result.plain_ruby_objects)}", result.result
        ]
      end
    end

    def report_on_github(rows, failures)
      summary = ENV["GITHUB_STEP_SUMMARY"]
      if summary
        lines = [markdown_table(rows)]
        lines.push("", *failures.map { |failure| "- #{failure}" }) unless failures.empty?
        File.write(summary, "#{lines.join("\n")}\n", mode: "a")
      end

      failures.each { |failure| puts "::error title=Benchmark::#{failure}" } if ENV["GITHUB_ACTIONS"]
    end

    # Columns aligned with spaces, for the terminal and the CI log
    def text_table(rows)
      table = [COLUMNS.keys, *rows]
      widths = COLUMNS.keys.each_index.map { |index| table.map { |row| row[index].length }.max }
      lines = table.map do |row|
        cells = row.each_with_index.map do |cell, index|
          COLUMNS.values[index] ? cell.rjust(widths[index]) : cell.ljust(widths[index])
        end
        cells.join("  ").rstrip
      end
      lines.join("\n")
    end

    def markdown_table(rows)
      alignment = COLUMNS.values.map { |right| right ? "---:" : "---" }
      lines = [COLUMNS.keys, alignment, *rows].map { |row| "| #{row.join(" | ")} |" }
      lines.join("\n")
    end

    # Instructions in thousands or millions, like 18.1k or 13.61M
    def instructions_count(value)
      (value < 1e6) ? "#{(value / 1e3).round(1)}k" : "#{(value / 1e6).round(2)}M"
    end

    # Whole number with thousands separators, like 2,523
    def number(value)
      value.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    end

    def ratio(value)
      format("%.3f", value)
    end
  end
end

exit(BenchmarkCheck.call ? 0 : 1)
