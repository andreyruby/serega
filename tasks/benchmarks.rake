# frozen_string_literal: true

namespace :benchmarks do
  desc "Checks the instructions and allocations of serega against the fastest other gem and the hand-written Hash"
  task :check do
    library = File.expand_path("../tmp/callgrind.so", __dir__)
    out_file = File.expand_path("../tmp/callgrind/out", __dir__)
    rm_rf File.dirname(out_file)
    mkdir_p File.dirname(out_file)
    sh "cc -shared -fPIC -O2 -o #{library} benchmarks/callgrind.c"

    # Callgrind counts only between the client requests of benchmarks/callgrind.c
    valgrind = "valgrind --tool=callgrind --quiet --instr-atstart=no --collect-atstart=no --callgrind-out-file=#{out_file}"
    env = {"CALLGRIND_LIBRARY" => library, "CALLGRIND_OUT_FILE" => out_file}
    # benchmarks/check.rb loads gemfiles/benchmarks.gemfile, thus it runs outside the current bundle
    Bundler.with_original_env { sh env, "#{valgrind} #{FileUtils::RUBY} benchmarks/check.rb" }
  end

  desc "Runs the benchmarks and updates the tables of benchmarks/README.md"
  task :full do
    Bundler.with_original_env { ruby "benchmarks/full.rb" }
  end
end
