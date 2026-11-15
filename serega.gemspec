# frozen_string_literal: true

require_relative "lib/serega/version"

Gem::Specification.new do |spec|
  spec.name = "serega"
  spec.version = Serega::VERSION
  spec.authors = ["Andrey"]
  spec.email = ["andreyruby@yandex.ru"]

  spec.summary = "Fast Ruby serializer: clients choose the fields, Serega loads only what they use"
  spec.description = <<~DESC.tr("\n", " ").strip
    Serializes Ruby objects to Hashes, JSON, Data or Struct. Clients choose
    the fields, and Serega preloads associations and runs batch loaders only
    for those fields, with no N+1 queries. No runtime dependencies.
  DESC
  spec.homepage = "https://github.com/andreyruby/serega"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "https://andreyruby.github.io/serega/"
  spec.metadata["changelog_uri"] = spec.homepage + "/blob/master/CHANGELOG.md"

  spec.files = Dir["lib/**/*.rb", "sig/**/*.rbs"] << "VERSION" << "README.md" << "LICENSE.txt"
  spec.require_paths = ["lib"]
  spec.extra_rdoc_files = ["README.md"]
  spec.rdoc_options = ["--markup", "markdown", "--main", "README.md", "--title", "Serega"]
end
