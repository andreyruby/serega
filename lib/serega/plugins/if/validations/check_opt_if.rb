# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module If
      #
      # Validator for attribute :if option
      #
      class CheckOptIf
        class << self
          #
          # Checks attribute :if option that must be [nil, Symbol, Proc, #call]
          #
          # @param opts [Hash] Attribute options
          #
          # @raise [SeregaError] Attribute validation error
          #
          # @return [void]
          #
          def call(opts)
            return unless opts.key?(:if)

            check_type(opts[:if])
          end

          private

          def check_type(value)
            return if value.is_a?(Symbol)
            raise SeregaError, must_be_callable unless value.respond_to?(:call)

            signature = SeregaUtils::MethodSignature.call(value, pos_limit: 2, keyword_args: [:ctx])
            raise SeregaError, signature_error unless valid_signature?(signature)
          end

          def must_be_callable
            "Invalid attribute option :if. It must be a Symbol, a Proc or respond to :call"
          end

          def valid_signature?(signature)
            case signature
            when "0"      # no parameters
              true
            when "1"      # (object)
              true
            when "2"      # (object, context)
              true
            when "1_ctx"  # (object, :ctx)
              true
            when "2_ctx"  # (object, context, :ctx)
              true
            else
              false
            end
          end

          def signature_error
            <<~ERROR.strip
              Invalid attribute option :if parameters, valid parameters signatures:
              - ()                     # no parameters
              - (object)               # one positional parameter
              - (object, context)      # two positional parameters
              - (object, :ctx)         # one positional parameter and :ctx keyword
              - (object, context, :ctx) # two positional parameters and :ctx keyword
            ERROR
          end
        end
      end
    end
  end
end
