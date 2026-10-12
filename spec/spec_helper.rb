# frozen_string_literal: true

Warning[:deprecated] = true
Warning[:experimental] = true
Warning[:performance] = true

# CI checks coverage on the latest Ruby only (COVERAGE=true in the workflow).
# Ruby 3.4 stops counting coverage after code runs in other Ractors.
coverage = ENV.fetch("COVERAGE") { ENV["CI"] ? "false" : "true" } == "true" && RUBY_VERSION >= "4.0"

if coverage && RUBY_ENGINE == "ruby" && (ARGV.none? || ARGV == ["spec"] || ARGV == ["spec/"])
  begin
    require "simplecov"

    SimpleCov.start do
      enable_coverage :branch
      minimum_coverage line: 100, branch: 100
    end
  rescue LoadError
  end
end

unless ENV["CI"]
  begin
    require "debug"
  rescue LoadError
  end
end

require "serega"

def load_plugin_code(*names)
  serializer_class = Class.new(Serega)
  names.each { |name| serializer_class.plugin(name) }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
