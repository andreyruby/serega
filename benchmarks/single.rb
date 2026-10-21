# frozen_string_literal: true

# One post with five attributes.

require_relative "support"

benchmark("single", :json)
benchmark("single", :hash)
