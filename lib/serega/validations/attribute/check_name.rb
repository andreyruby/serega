# frozen_string_literal: true

class Serega
  # @private
  module SeregaValidations
    # @private
    module Attribute
      #
      # Attribute `name` parameter validator
      #
      # @private
      class CheckName
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
            name = SeregaUtils::SymbolName.call(name)
            raise SeregaError, message(name) unless FORMAT.match?(name)
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
