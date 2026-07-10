# frozen_string_literal: true

class Serega
  module SeregaValidations
    #
    # Attribute parameters validators
    #
    module Attribute
      #
      # Attribute `block` parameter validator
      #
      class CheckBlock
        # Explains the changed attribute block behavior. Shown when the block
        # looks like an old-style value block — it accepts parameters or
        # defines no attributes.
        ERROR_MESSAGE =
          "Attribute block now defines a nested serializer:" \
          " it is executed in the context of a new serializer class and must define its attributes." \
          " Defining the attribute value with a block is not supported anymore," \
          " use the `value: <callable>` option instead."

        class << self
          #
          # Checks block parameter provided with attribute.
          #
          # The block defines attributes of a nested anonymous serializer, so
          # it is executed in the context of that serializer and must accept
          # no parameters.
          #
          # @example
          #   attribute :statistics, method: :itself do
          #     attribute :likes_count
          #     attribute :comments_count
          #   end
          #
          # @param block [Proc] Block that defines nested serializer attributes
          #
          # @raise [SeregaError] SeregaError that block has invalid arguments
          #
          # @return [void]
          #
          def call(block)
            return unless block

            signature = SeregaUtils::MethodSignature.call(block, pos_limit: 0)
            raise SeregaError, ERROR_MESSAGE unless signature == "0"
          end
        end
      end
    end
  end
end
