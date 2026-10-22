# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Attribute # :nodoc:
      #
      # Validator for attribute :if, :unless, :if_value and :unless_value options
      #
      class CheckOptCondition # :nodoc:
        # Options whose condition receives the serialized value, not the object
        VALUE_OPTIONS = %i[if_value unless_value].freeze

        # Signatures from MethodSignature: up to two positional parameters and
        # the :ctx keyword
        VALID_SIGNATURES = %w[0 1 2 1_ctx 2_ctx].freeze

        class << self
          # Checks the condition option `name`: a Symbol, a Proc or an object
          # that responds to :call
          def call(opts, name)
            return unless opts.key?(name)

            parameter = VALUE_OPTIONS.include?(name) ? "value" : "object"
            check_type(opts[name], name, parameter)
          end

          private

          def check_type(condition, name, parameter)
            return if condition.is_a?(Symbol)
            raise SeregaError, must_be_callable(name) unless condition.respond_to?(:call)

            signature = SeregaUtils::MethodSignature.call(condition, pos_limit: 2, keyword_args: [:ctx])
            raise SeregaError, signature_error(name, parameter) unless VALID_SIGNATURES.include?(signature)
          end

          def must_be_callable(name)
            "Invalid attribute option #{name.inspect}. It must be a Symbol, a Proc or respond to :call"
          end

          def signature_error(name, parameter)
            <<~ERROR.strip
              Invalid attribute option #{name.inspect} parameters, valid parameters signatures:
              - ()
              - (#{parameter})
              - (#{parameter}, context)
              - (#{parameter}, :ctx)
              - (#{parameter}, context, :ctx)
            ERROR
          end
        end
      end
    end
  end
end
