# frozen_string_literal: true

# 100 posts with relations, without the post body and the comment creation
# times. Only serega and panko_serializer have runtime `except`.

require_relative "support"

benchmark("except", :json)
benchmark("except", :hash)
