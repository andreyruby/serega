# frozen_string_literal: true

# Shared setup of the benchmark scripts. Each script measures one case of
# `BenchmarkCases` with `benchmark`. The gems come from gemfiles/benchmarks.gemfile.

ENV["BUNDLE_GEMFILE"] = File.expand_path("../gemfiles/benchmarks.gemfile", __dir__)
require "bundler/setup"
require "benchmark/ips"
require_relative "cases"

# Checks every report of the case returns the data of the "plain ruby" report,
# then measures them. FAST=1 runs a short round.
def benchmark(name, format)
  reports = BenchmarkCases.public_send(name).fetch(format)
  BenchmarkCases.check(format, reports)

  puts "#{RUBY_DESCRIPTION}, #{name} #{format}: #{reports.size} outputs match plain ruby"
  Benchmark.ips do |x|
    x.config(time: 0.25, warmup: 0.1) if ENV["FAST"]
    reports.each { |report, block| x.report(report, &block) }
    x.compare!
  end
end
