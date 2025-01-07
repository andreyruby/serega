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
        class << self
          #
          # Checks block parameter provided with attribute.
          # Must have up to two arguments - object and context. Context can be
          # also provided as keyword argument :ctx.
          #
          # @example without arguments
          #   attribute(:email) { CONSTANT_EMAIL }
          #
          # @example with one argument
          #   attribute(:email) { |obj| obj.confirmed_email }
          #
          # @example with two arguments
          #   attribute(:email) { |obj, context| context['is_current'] ? obj.email : nil }
          #
          # @example with one argument and keyword context
          #   attribute(:email) { |obj, ctx:| obj.email if ctx[:show] }
          #
          # @param block [Proc] Block that returns serialized attribute value
          #
          # @raise [SeregaError] SeregaError that block has invalid arguments
          #
          # @return [void]
          #
          def call(block)
            return unless block

            check_block(block)
          end

          private

          def check_block(block)
            signature = SeregaUtils::MethodSignature.call(block, pos_limit: 2, keyword_args: [:ctx, :batches])

            raise SeregaError, signature_error unless valid_signature?(signature)
          end

          def valid_signature?(signature)
            case signature
            when "0"             # no parameters
              true
            when "1"             # call(object)
              true
            when "1_ctx"         # call(object, ctx:)
              true
            when "1_batches"     # call(object, batches:)
              true
            when "1_batches_ctx" # call(object, batches:, ctx:)
              true
            when "2"             # call(object, context)
              true
            when "2_batches_ctx" # call(object, context, batches:, ctx:) (proc with no params)
              true
            else
              false
            end
          end

          def signature_error
            <<~ERROR.strip
              Invalid attribute block parameters, valid parameters signatures:
              - ()                       # no parameters
              - (object)                 # one positional parameter
              - (object, ctx:)           # one positional parameter and :ctx keyword
              - (object, batches:)       # one positional parameter and :batches keyword
              - (object, ctx:, batches:) # one positional parameter, :ctx, and :batches keywords
              - (object, context)        # two positional parameters
            ERROR
          end
        end
      end
    end
  end
end
