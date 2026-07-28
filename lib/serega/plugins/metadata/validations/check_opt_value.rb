# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module Metadata
      class MetaAttribute
        #
        # Validator for meta_attribute :value option
        #
        # @private
        class CheckOptValue
          class << self
            #
            # Checks attribute :value option
            #
            # @param opts [Hash] Attribute options
            #
            # @raise [SeregaError] SeregaError that option has invalid value
            #
            # @return [void]
            #
            def call(opts, block = nil)
              return unless opts.key?(:value)

              check_usage_with_other_params(opts, block)

              check_value(opts[:value])
            end

            private

            def check_usage_with_other_params(opts, block)
              raise SeregaError, "Option :value can not be used together with option :const" if opts.key?(:const)
              raise SeregaError, "Option :value can not be used together with block" if block
            end

            def check_value(value)
              check_value_type(value)

              signature = SeregaUtils::MethodSignature.call(value, pos_limit: 2, keyword_args: [])

              raise SeregaError, params_count_error unless %w[0 1 2].include?(signature)
            end

            def check_value_type(value)
              raise SeregaError, type_error if !value.is_a?(Proc) && !value.respond_to?(:call)
            end

            def type_error
              "Option :value value must be a Proc or respond to #call"
            end

            def params_count_error
              "Option :value value can have maximum 2 parameters (object(s), context)"
            end
          end
        end
      end
    end
  end
end
