# frozen_string_literal: true

# Shared setup of the benchmark scripts. Each script measures one case of
# `BenchmarkCases` with `benchmark`. The gems come from gemfiles/benchmarks.gemfile.

ENV["BUNDLE_GEMFILE"] = File.expand_path("../gemfiles/benchmarks.gemfile", __dir__)
require "bundler/setup"
require "benchmark/ips"
require_relative "cases"

# Output of benchmark-ips without the Ruby description, which it prints at the
# start of each case, as `benchmark` prints it once
class BenchmarkStreamReport < Benchmark::IPS::Job::StreamReport
  def start_warming
    @out.puts "Warming up --------------------------------------"
  end
end

# Titles of the benchmark cases in the output
module BenchmarkTitle
  class << self
    # Prints the title of a case, bold in a terminal: after the Ruby
    # description and an empty line for the first case, and after an empty
    # line for the next ones, as the comparison before them ends with one.
    def print(text)
      if @printed
        puts ""
      else
        puts RUBY_DESCRIPTION, ""
        @printed = true
      end

      title = "=== #{text} ==="
      puts($stdout.tty? ? "\e[1m#{title}\e[0m" : title)
    end
  end
end

# Checks every report of the case returns the data of the "plain ruby" report,
# then measures them and returns the Benchmark::IPS report. A report measures
# for 1 second after a warmup of half of it; TIME=5 measures for 5 seconds, and
# FAST=1 for 0.25 seconds.
def benchmark(name, format)
  reports = BenchmarkCases.public_send(name).fetch(format)
  BenchmarkCases.check(format, reports)

  BenchmarkTitle.print("#{name} #{format}: #{reports.size} outputs match plain ruby")
  Benchmark.ips do |x|
    time = ENV["FAST"] ? 0.25 : Float(ENV.fetch("TIME", "1"))
    x.config(time: time, warmup: time / 2, quiet: true, suite: BenchmarkStreamReport.new(x))
    reports.each { |report, block| x.report(report, &block) }
    x.compare!
  end
end
