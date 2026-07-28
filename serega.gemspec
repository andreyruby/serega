# frozen_string_literal: true

require_relative "lib/serega/version"

Gem::Specification.new do |spec|
  spec.name = "serega"
  spec.version = Serega::VERSION
  spec.authors = ["Andrey"]
  spec.email = ["andreyruby@yandex.ru"]

  spec.summary = "Ruby Serializer"
  spec.description = <<~DESC.tr("\n", " ").strip
    Serializes Ruby objects into Hashes, ready for further conversion to JSON
    or other formats, with a simple DSL for selecting fields and solving N+1
    queries through batch loading. Extendable through a Roda/Shrine-style
    plugin system, with built-in plugins for presenters, formatters, camel_case
    keys, depth limiting, and more. No runtime dependencies.
  DESC
  spec.homepage = "https://github.com/andreyruby/serega"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "https://www.rubydoc.info/gems/serega"
  spec.metadata["changelog_uri"] = spec.homepage + "/blob/master/CHANGELOG.md"

  spec.files = Dir["lib/**/*.rb"] << "VERSION" << "README.md" << "LICENSE.txt"
  spec.require_paths = ["lib"]
end
