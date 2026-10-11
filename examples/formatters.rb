# frozen_string_literal: true

require "bundler/inline"

gemfile(true, quiet: true) do
  source "https://rubygems.org"
  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "serega", path: File.join(File.dirname(__FILE__), "..")
end

class AppSerializer < Serega
  formatter :day, ->(value) { value.strftime("%Y-%m") }
  formatter :bool, ->(value) { ![0, "", nil, "false"].include?(value) }
end

class Serializer < AppSerializer
  attribute :date1, format: :day
  attribute :date2, format: :day

  attribute :bool1, format: :bool
  attribute :bool2, format: :bool
  attribute :bool3, format: :bool
end

require "time"
require "ostruct"

data = OpenStruct.new(
  date1: Date.new(2020, 1, 2),
  date2: Date.new(2021, 2, 3),
  bool1: 1,
  bool2: 0,
  bool3: "false"
)

response = Serializer.new.to_h(data)

require "json"
puts JSON.pretty_generate(response)
