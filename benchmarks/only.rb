# frozen_string_literal: true

# 100 posts with relations, keeping the post id and title, the author name and
# the comment bodies. alba, blueprinter and oj_serializers have no runtime
# field selection.

require_relative "support"

benchmark("only", :json)
benchmark("only", :hash)
