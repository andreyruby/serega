# frozen_string_literal: true

# 100 posts with five attributes.

require_relative "support"

benchmark("collection", :json)
benchmark("collection", :hash)
