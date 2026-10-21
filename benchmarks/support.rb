# frozen_string_literal: true

# Shared setup of the benchmark scripts. Each script measures one case of
# `BenchmarkCases` with `benchmark`. The gems come from gemfiles/benchmarks.gemfile.

ENV["BUNDLE_GEMFILE"] = File.expand_path("../gemfiles/benchmarks.gemfile", __dir__)
require "bundler/setup"
require "benchmark/ips"
require_relative "cases"

# Checks every report of the case returns the data of the "plain ruby" report,
# then measures them and returns the Benchmark::IPS report. A report measures
# for 1 second after a warmup of half of it; TIME=5 measures for 5 seconds, and
# FAST=1 for 0.25 seconds.
def benchmark(name, format)
  reports = BenchmarkCases.public_send(name).fetch(format)
  BenchmarkCases.check(format, reports)

  puts "#{RUBY_DESCRIPTION}, #{name} #{format}: #{reports.size} outputs match plain ruby"
  Benchmark.ips do |x|
    time = ENV["FAST"] ? 0.25 : Float(ENV.fetch("TIME", "1"))
    x.config(time: time, warmup: time / 2)
    reports.each { |report, block| x.report(report, &block) }
    x.compare!
  end
end
