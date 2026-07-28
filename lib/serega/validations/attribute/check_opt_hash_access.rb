# frozen_string_literal: true

class Serega
  # @private
  module SeregaValidations
    # @private
    module Attribute
      #
      # Attribute `:hash_access` option validator
      #
      # @private
      class CheckOptHashAccess
        class << self
          #
          # Checks attribute :hash_access option
          #
          # @param opts [Hash] Attribute options
          #
          # @raise [SeregaError] Attribute validation error
          #
          # @return [void]
          #
          def call(opts)
            return unless opts.key?(:hash_access)

            value = opts[:hash_access]
            check_value(value)
            check_usage_with_other_params(opts) if value
          end

          private

          def check_value(value)
            case value
            when true, false then nil
            when Symbol then check_mode(value)
            when Hash
              Utils::CheckAllowedKeys.call(value, %i[mode allow_missing_key], :hash_access)
              check_mode(value[:mode]) if value.key?(:mode)
              check_allow_missing_key(value[:allow_missing_key]) if value.key?(:allow_missing_key)
            else
              raise SeregaError,
                "Invalid option :hash_access => #{value.inspect}." \
                " It must be a Boolean, a Symbol mode (:symbol, :string)" \
                " or a Hash with :mode and :allow_missing_key keys"
            end
          end

          def check_mode(mode)
            return if AttributeValueResolvers::HashAccessResolver::MODES.include?(mode)

            raise SeregaError, "Invalid :hash_access mode #{mode.inspect}. Allowed modes: :symbol, :string"
          end

          def check_allow_missing_key(allow_missing_key)
            return if allow_missing_key == true || allow_missing_key == false

            raise SeregaError, "Invalid :hash_access option :allow_missing_key => #{allow_missing_key.inspect}. Must be a Boolean"
          end

          # The :const, :value and :batch options do not read the serialized
          # object by attribute name, so hash access can not affect them.
          # Delegated attributes configure hash access per step with the
          # `delegate: {to_hash_access:, hash_access:}` sub-options.
          def check_usage_with_other_params(opts)
            raise SeregaError, "Option :hash_access can not be used together with option :const" if opts.key?(:const)
            raise SeregaError, "Option :hash_access can not be used together with option :value" if opts.key?(:value)
            raise SeregaError, "Option :hash_access can not be used together with option :batch" if opts.key?(:batch)

            if opts.key?(:delegate)
              raise SeregaError,
                "Option :hash_access can not be used together with option :delegate." \
                " Use the delegate :to_hash_access (intermediate step) and" \
                " :hash_access (final step) sub-options instead"
            end
          end
        end
      end
    end
  end
end
