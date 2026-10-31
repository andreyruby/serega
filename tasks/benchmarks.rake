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

  namespace :docker do
    # Runs a benchmarks task in the image of benchmarks/Dockerfile, with 2 GB
    # of memory. The image has no main bundle, thus its rake loads only this
    # file. TIME, FAST and RUBY_YJIT_ENABLE pass through.
    run = lambda do |name|
      sh "docker build --quiet --file benchmarks/Dockerfile --tag serega-benchmarks ."

      env = %w[TIME FAST RUBY_YJIT_ENABLE].select { |variable| ENV.key?(variable) }.flat_map { |variable| ["--env", variable] }
      tty = $stdout.tty? ? ["--tty"] : []
      root = File.expand_path("..", __dir__)
      sh "docker", "run", "--rm", *tty, "--memory=2g", *env, "--volume", "#{root}:/serega",
        "serega-benchmarks", "rake", "--require", "bundler", "--rakefile", "tasks/benchmarks.rake", "benchmarks:#{name}"
    end

    desc "Runs benchmarks:full in Docker, and updates the tables of benchmarks/README.md"
    task(:full) { run.call("full") }

    desc "Runs benchmarks:check in Docker, where Valgrind runs on any host"
    task(:check) { run.call("check") }
  end
end
