# frozen_string_literal: true

namespace :benchmarks do
  desc "Checks serega against the fastest other gem and the hand-written Hash of each benchmark case"
  task :check do
    # benchmarks/check.rb loads gemfiles/benchmarks.gemfile, thus it runs outside the current bundle
    Bundler.with_original_env { ruby "benchmarks/check.rb" }
  end

  desc "Runs the benchmarks and updates the tables of benchmarks/README.md"
  task :full do
    Bundler.with_original_env { ruby "benchmarks/full.rb" }
  end
end
