# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Attribute # :nodoc:
      #
      # Attribute `:value` option validator
      #
      class CheckOptValue # :nodoc:
        class << self
          # Checks attribute :value option
          def call(opts)
            return unless opts.key?(:value)

            check_value(opts[:value])
          end

          private

          def check_value(value)
            check_value_type(value)
            signature = SeregaUtils::MethodSignature.call(value, pos_limit: 2, keyword_args: %i[ctx batches])
            raise SeregaError, signature_error unless valid_signature?(signature)
          end

          def check_value_type(value)
            raise SeregaError, type_error if !value.is_a?(Proc) && !value.respond_to?(:call)
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
            when "1_batches_ctx" # call(object, ctx:, batches:)
              true
            when "2"             # call(object, context)
              true
            when "2_batches_ctx" # call(object, context, ctx:, batches:) (proc with no params)
              true
            else
              false
            end
          end

          def signature_error
            <<~ERROR.strip
              Invalid attribute :value option parameters, valid parameters signatures:
              - ()                       # no parameters
              - (object)                 # one positional parameter
              - (object, ctx:)           # one positional parameter and :ctx keyword
              - (object, batches:)       # one positional parameter and :batches keyword
              - (object, ctx:, batches:) # one positional parameter, :ctx, and :batches keywords
              - (object, context)        # two positional parameters
            ERROR
          end

          def type_error
            "Option :value value must be a Proc or respond to #call"
          end
        end
      end
    end
  end
end
