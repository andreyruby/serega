# frozen_string_literal: true

# Runs the block in a new Ractor with the arguments, and returns the block
# value. Raises the error that the block raised.
#
# Coverage does not count code that runs in other Ractors, thus write the
# block on the line of the call.
def run_in_ractor(*args, &block)
  experimental = Warning[:experimental]
  report_on_exception = Thread.report_on_exception
  Warning[:experimental] = false
  Thread.report_on_exception = false
  ractor = Ractor.new(*args, &block)
  # :nocov:
  ractor.respond_to?(:value) ? ractor.value : ractor.take
  # :nocov:
rescue Ractor::RemoteError => error
  raise error.cause
ensure
  Warning[:experimental] = experimental
  Thread.report_on_exception = report_on_exception
end
