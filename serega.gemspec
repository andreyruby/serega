# frozen_string_literal: true

require_relative "lib/serega/version"

Gem::Specification.new do |spec|
  spec.name = "serega"
  spec.version = Serega::VERSION
  spec.authors = ["Andrey Glushkov"]
  spec.email = ["aglushkov@shakuro.com"]

  spec.summary = "JSON Serializer"
  spec.description = <<~DESC
    JSON Serializer

    - Simple and clear DSL
    - Ability to manually select serialized fields
    - Multiple ways to solve N+1 problems
    - Built-in presenter
    - No dependencies
    - Plugin system as in Roda or Shrine
  DESC
  spec.homepage = "https://github.com/aglushkov/serega"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "https://www.rubydoc.info/gems/serega"
  spec.metadata["changelog_uri"] = spec.homepage + "/blob/master/CHANGELOG.md"

  spec.files = Dir["lib/**/*.rb"] << "VERSION" << "README.md"
  spec.require_paths = ["lib"]
end
