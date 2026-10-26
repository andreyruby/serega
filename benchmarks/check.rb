# frozen_string_literal: true

# Checks each benchmark case: Serega must be at most 2% slower than the fastest
# other gem, and at most as slow as the hand-written Hash, with 15% more in the
# single case and 10% more in the collection case. Prints a table of the times, adds it to the
# GitHub job summary on CI, and exits with 1 when a case fails. Run it with
# `rake benchmarks:check`.

require_relative "support"

module BenchmarkCheck
  # The fastest other gem by case and format, see README.md
  RIVALS = {
    ["single", :json] => "alba",
    ["single", :hash] => "oj_serializers",
    ["collection", :json] => "oj_serializers",
    ["collection", :hash] => "oj_serializers",
    ["relations", :json] => "oj_serializers",
    ["relations", :hash] => "oj_serializers",
    ["only", :json] => "panko_serializer",
    ["only", :hash] => "panko_serializer",
    ["except", :json] => "panko_serializer",
    ["except", :hash] => "panko_serializer"
  }.freeze

  # Rounds of each serializer per case, with alternating serializers
  ROUNDS = 15

  # Time of the batches of a case, in seconds. Shorter rounds spread the close
  # cases by several percent.
  CASE_TIME = 0.5

  # Calls of each serializer before the rounds at least, as YJIT compiles a
  # method after 30 calls, and Serega calls some methods once per serialization
  WARMUP_CALLS = 50

  # How much slower than the hand-written Hash Serega may be, by case. In the
  # single and collection cases both build each Hash with one method, and
  # Serega takes 1.04 to 1.09 of its time for one object, and 0.98 to 1.01 for
  # a collection. With relations the hand-written code calls a method per
  # related record, and Serega takes 0.79 to 0.97 of its time.
  MAX_PLAIN_RUBY_RATIOS = {
    "single" => 1.15, "collection" => 1.1, "relations" => 1.0, "only" => 1.0, "except" => 1.0
  }.freeze

  # How much slower than the fastest other gem Serega may be. In the collection
  # Hash case Serega, the other gem and the hand-written Hash take the same
  # time, and each wins some runs.
  MAX_RIVAL_RATIO = 1.02

  # Columns of the table, and whether each is right-aligned
  COLUMNS = {
    "Case" => false, "Rival" => false, "Serega" => true, "Rival time" => true, "Hand-written" => true,
    "Serega/Rival" => true, "Serega/Hand-written" => true, "Result" => false
  }.freeze

  # Measured times of one case, in seconds
  Result = Struct.new(:name, :output_format, :rival, :serega_time, :rival_time, :plain_ruby_time) do
    def max_plain_ruby_ratio
      MAX_PLAIN_RUBY_RATIOS.fetch(name)
    end

    def label
      "#{name} #{output_format}"
    end

    def rival_ratio
      serega_time / rival_time
    end

    def plain_ruby_ratio
      serega_time / plain_ruby_time
    end

    def lost?
      rival_ratio > MAX_RIVAL_RATIO
    end

    def slowed_down?
      plain_ruby_ratio > max_plain_ruby_ratio
    end

    def passed?
      !lost? && !slowed_down?
    end

    # Short reasons for the Result column
    def result
      return "ok" if passed?

      reasons = []
      reasons << "lost to #{rival}" if lost?
      reasons << "over #{max_plain_ruby_ratio}x the hand-written" if slowed_down?
      "FAILED: #{reasons.join(", ")}"
    end

    # @return [Array<String>] Why the case fails, empty when it passes
    def failures
      failures = []
      failures << format("Serega takes %.2fx the time of %s, the limit is %.2fx", rival_ratio, rival, MAX_RIVAL_RATIO) if lost?
      if slowed_down?
        failures << format("Serega takes %.2fx the time of the hand-written Hash, the limit is %.2fx", plain_ruby_ratio, max_plain_ruby_ratio)
      end
      failures
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

    # Measures one case. A busy machine can slow one measurement, thus a case
    # that fails is measured again for longer.
    def check(name, format, rival)
      reports = BenchmarkCases.public_send(name).fetch(format)
      BenchmarkCases.check(format, reports)
      serializers = reports.values_at("serega", rival, "plain ruby")

      result = Result.new(name, format, rival, *median_call_times(serializers, CASE_TIME))
      result = Result.new(name, format, rival, *median_call_times(serializers, CASE_TIME * 3)) unless result.passed?
      result
    end

    # Median time of one call of each serializer, in seconds. Each serializer
    # measures one batch before the rounds, to size its batches.
    def median_call_times(serializers, case_time)
      batch_time = case_time / (ROUNDS + 1) / serializers.size
      batch_sizes = serializers.map { |serializer| batch_size(serializer, batch_time) }
      times = serializers.map { [] }

      ROUNDS.times do |round|
        # Alternate which serializer goes first
        order = round.even? ? serializers.each_index : serializers.each_index.reverse_each
        order.each do |index|
          serializer = serializers[index]
          calls = batch_sizes[index]
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          calls.times { serializer.call }
          times[index] << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) / calls
        end
      end

      times.map { |serializer_times| serializer_times.sort[ROUNDS / 2] }
    end

    # Calls the serializer for the batch time, and the warmup calls at least,
    # and returns the number of calls in the batch time
    def batch_size(serializer, batch_time)
      WARMUP_CALLS.times { serializer.call }

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      calls = 0

      loop do
        serializer.call
        calls += 1
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) - started >= batch_time
      end

      calls
    end

    def rows(results)
      results.map do |result|
        [
          result.label, result.rival,
          duration(result.serega_time), duration(result.rival_time), duration(result.plain_ruby_time),
          ratio(result.rival_ratio), ratio(result.plain_ruby_ratio), result.result
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

    def duration(seconds)
      if seconds < 1e-6 then "#{(seconds * 1e9).round} ns"
      elsif seconds < 1e-3 then "#{(seconds * 1e6).round(1)} µs"
      else "#{(seconds * 1e3).round(2)} ms"
      end
    end

    def ratio(value)
      format("%.2f", value)
    end
  end
end

exit(BenchmarkCheck.call ? 0 : 1)
