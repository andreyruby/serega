# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in serega.gemspec
gemspec

gem "rake", "~> 13.0"
gem "ostruct", "~> 0.6.3"
gem "rspec", "~> 3.0", require: false
gem "standard", "~> 1.42", require: false
gem "simplecov", "~> 0.21", require: false
gem "rubocop-rake", "~> 0.6", require: false
gem "rubocop-rspec", "~> 3.2", require: false
gem "rubocop-performance", "~> 1.22", require: false
gem "redcarpet", "~> 3.5", require: false
# Can be used in test like:
#  require 'allocation_stats'
#
#  stats = AllocationStats.trace do
#    subject
#  end
#
#  puts stats.allocations(alias_paths: true).group_by(:sourcefile, :sourceline).to_text
#
gem "allocation_stats", require: false
gem "yard", require: false
gem "mdl", "~> 0.13", require: false

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1")
  gem "debug", ">= 1.0"
else
  gem "pry-byebug", "~> 3.9"
end

gem "activerecord", "~> 8.0"
gem "sqlite3", platforms: [:ruby]
gem "activerecord-jdbcsqlite3-adapter", platforms: [:jruby]
