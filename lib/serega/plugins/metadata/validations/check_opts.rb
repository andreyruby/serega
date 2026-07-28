# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module Metadata
      class MetaAttribute
        #
        # Validator for meta_attribute options
        #
        # @private
        class CheckOpts
          class << self
            #
            # Validates meta_attribute options
            # Checks used options are allowed and then checks options values.
            #
            # @param opts [Hash] Attribute options
            # @param block [Proc] Attribute block
            # @param allowed_keys [Array<Symbol>] Allowed options keys
            #
            # @raise [SeregaError] when attribute has invalid options
            #
            # @return [void]
            #
            def call(opts, block, allowed_keys)
              check_allowed_options_keys(opts, allowed_keys)
              check_each_opt(opts, block)
              check_any_value_provided(opts, block)
            end

            private

            def check_allowed_options_keys(opts, allowed_keys)
              opts.each_key do |key|
                next if allowed_keys.include?(key.to_sym)

                allowed = allowed_keys.map(&:inspect).join(", ")
                raise SeregaError, "Invalid option #{key.inspect}. Allowed options are: #{allowed}"
              end
            end

            def check_each_opt(opts, block)
              CheckOptHideEmpty.call(opts)
              CheckOptHideNil.call(opts)
              CheckOptValue.call(opts, block)
              CheckOptConst.call(opts, block)
            end

            def check_any_value_provided(opts, block)
              return if opts.key?(:const) || opts.key?(:value) || block

              raise SeregaError, "Please provide block argument or add :value or :const option"
            end
          end
        end
      end
    end
  end
end
