# frozen_string_literal: true

class Serega
  #
  # Utilities
  #
  module SeregaUtils # :nodoc:
    #
    # Utility to write snake_case names in camelCase
    #
    class CamelCase # :nodoc:
      class << self
        # Returns the name in camelCase: drops each underscore before a
        # lowercase letter or a digit and upcases the letter. Other characters
        # stay as they are.
        def call(name)
          name.to_s.gsub(/_[a-z\d]/) { |match| match[1].upcase }.to_sym
        end
      end
    end
  end
end
