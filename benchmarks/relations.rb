# frozen_string_literal: true

# 100 posts with their author and 10 comments each.

require_relative "support"

benchmark("relations", :json)
benchmark("relations", :hash)
