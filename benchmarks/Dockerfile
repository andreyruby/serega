# Image of the benchmarks: Ruby 4.0.7, the gems of gemfiles/benchmarks.gemfile,
# and Valgrind for `rake benchmarks:check`. `rake benchmarks:docker:full` and
# `rake benchmarks:docker:check` build it and run the task in it, with the
# repository mounted at /serega.
FROM ruby:4.0.7-slim-trixie

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential valgrind \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /serega

# The gemspec of the benchmarks gemfile reads the version
COPY VERSION serega.gemspec ./
COPY lib/serega/version.rb lib/serega/
COPY gemfiles/benchmarks.gemfile gemfiles/benchmarks.gemfile.lock gemfiles/
RUN BUNDLE_GEMFILE=gemfiles/benchmarks.gemfile bundle install --jobs 4
