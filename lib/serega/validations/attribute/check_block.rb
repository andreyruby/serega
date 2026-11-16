# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    #
    # Attribute parameters validators
    #
    module Attribute # :nodoc:
      #
      # Attribute `block` parameter validator
      #
      class CheckBlock # :nodoc:
        # Error of a block that looks like a value block: it accepts
        # parameters or defines no attributes.
        ERROR_MESSAGE =
          "Attribute block defines a nested serializer and must define its attributes\n" \
          "(hint: to compute the attribute value, use the `value: <callable>` option)"

        class << self
          # Checks block parameter provided with attribute.
          #
          # The block defines attributes of a nested anonymous serializer, so
          # it is executed in the context of that serializer and must accept
          # no parameters.
          #
          #   attribute :statistics, method: :itself do
          #     attribute :likes_count
          #     attribute :comments_count
          #   end
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
