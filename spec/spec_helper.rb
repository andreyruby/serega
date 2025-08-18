# frozen_string_literal: true

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.7.0")
  Warning[:deprecated] = true
  Warning[:experimental] = true
  Warning[:performance] = true if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.3.0")
end

if RUBY_ENGINE == "ruby" && RUBY_VERSION.start_with?("3.4.") && (ARGV.none? || ARGV == ["spec"] || ARGV == ["spec/"])
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
    if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1.0")
      require "debug"
    else
      require "pry-byebug"
    end
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
