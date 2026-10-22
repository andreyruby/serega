# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Utils # :nodoc:
      #
      # Validator of a hash access value: the attribute :hash_access option and
      # the delegate :to_hash_access and :hash_access sub-options
      #
      class CheckHashAccessValue # :nodoc:
        class << self
          # Checks that the `key` value is a Boolean, a Symbol mode or a Hash
          # with :mode and :allow_missing_key
          def call(opts, key)
            return unless opts.key?(key)

            value = opts[key]
            case value
            when true, false then nil
            when Symbol then check_mode(value)
            when Hash
              CheckAllowedKeys.call(value, %i[mode allow_missing_key], key)
              check_mode(value[:mode]) if value.key?(:mode)
              CheckOptIsBool.call(value, :allow_missing_key)
            else
              raise SeregaError,
                "Invalid option #{key.inspect} => #{value.inspect}." \
                " It must be a Boolean, a Symbol mode (:symbol, :string)" \
                " or a Hash with :mode and :allow_missing_key keys"
            end
          end

          private

          def check_mode(mode)
            return if AttributeValueResolvers::HashAccessResolver::MODES.include?(mode)

            raise SeregaError, "Invalid :hash_access mode #{mode.inspect}. Allowed modes: :symbol, :string"
          end
        end
      end
    end
  end
end
