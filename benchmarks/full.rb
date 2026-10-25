# frozen_string_literal: true

# Runs every benchmark case, and writes the serializations per second of each
# gem to the tables of README.md and benchmarks/README.md, the lines between
# `<!-- benchmarks:json -->` or `<!-- benchmarks:hash -->` and their `:end`
# comment, then redraws the chart of the JSON table. Run it with
# `rake benchmarks:full`.

require_relative "support"
require_relative "chart"

module BenchmarkTables
  # Cases in the order of the table columns
  CASES = %w[single collection relations only except].freeze

  HEADER = ["Serializer", "1 post", "100 posts", "100 posts with relations", "`only:`", "`except:`"].freeze

  # Row label of each report, in the order of the table rows
  ROWS = {
    "serega" => "**Serega**",
    "oj_serializers" => "oj_serializers",
    "panko_serializer" => "panko_serializer",
    "alba" => "alba",
    "blueprinter" => "blueprinter",
    "active_model_serializers" => "active_model_serializers",
    "plain ruby" => "*hand-written Hash*"
  }.freeze

  # Files with a table, by format
  FILES = {
    json: [File.expand_path("../README.md", __dir__), File.expand_path("README.md", __dir__)],
    hash: [File.expand_path("README.md", __dir__)]
  }.freeze

  class << self
    # Measures every case in each format and writes the tables
    #
    # @return [void]
    def call
      FILES.each do |format, paths|
        table = table(measure(format))
        paths.each { |path| write_table(path, format, table) }
      end
    end

    private

    # Serializations per second by report and case
    def measure(format)
      ips = Hash.new { |hash, report| hash[report] = {} }

      CASES.each do |name|
        benchmark(name, format).entries.each { |entry| ips[entry.label][name] = entry.ips }
      end

      ips
    end

    # Markdown table with the cells padded to the column width. A gem without
    # a case, for example without runtime field selection, gets "—".
    def table(ips)
      rows = ROWS.map do |report, label|
        values = CASES.map { |name| ips[report].key?(name) ? number(ips[report][name]) : "—" }
        [label, *values]
      end

      widths = HEADER.each_index.map { |index| [HEADER, *rows].map { |row| row[index].length }.max }
      separator = widths.each_with_index.map { |width, index| index.zero? ? "-" * (width + 2) : "#{"-" * (width + 1)}:" }

      lines = [HEADER, *rows].map do |row|
        cells = row.each_with_index.map { |cell, index| index.zero? ? cell.ljust(widths[index]) : cell.rjust(widths[index]) }
        "| #{cells.join(" | ")} |"
      end
      lines.insert(1, "|#{separator.join("|")}|")
      lines.join("\n")
    end

    # Whole number with thousands separators, like 2,024,026
    def number(value)
      value.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    end

    def write_table(path, format, table)
      start = "<!-- benchmarks:#{format} -->\n"
      finish = "<!-- benchmarks:#{format}:end -->"
      text = File.read(path)
      pattern = /#{Regexp.escape(start)}.*?(?=#{Regexp.escape(finish)})/m
      raise "#{path} has no #{start.strip} and #{finish} comments" unless text.match?(pattern)

      File.write(path, text.sub(pattern) { "#{start}#{table}\n" })
      puts "Updated the #{format} table of #{path}"
    end
  end
end

BenchmarkTables.call
BenchmarkChart.call
