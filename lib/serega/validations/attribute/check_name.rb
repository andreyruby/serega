# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Attribute # :nodoc:
      #
      # Attribute `name` parameter validator
      #
      class CheckName # :nodoc:
        # Regexp for valid attribute name
        FORMAT = /\A[\w~-]+\z/

        class << self
          #
          # Checks allowed characters.
          # Allowed characters: "a-z", "A-Z", "0-9", "_", "-", "~".
          #
          # @param name [String, Symbol] Attribute name
          #
          # @raise [SeregaError] when name has invalid format
          # @return [void]
          #
          def call(name)
            raise SeregaError, message(name.to_s) unless FORMAT.match?(name)
          end

          private

          def message(name)
            <<~MESSAGE.tr("\n", "")
              Invalid attribute name = #{name.inspect}.
               Allowed characters: "a-z", "A-Z", "0-9", "_", "-", "~"
            MESSAGE
          end
        end
      end
    end
  end
end
