# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Attribute # :nodoc:
      #
      # Attribute `:hash_access` option validator
      #
      class CheckOptHashAccess # :nodoc:
        class << self
          # Checks attribute :hash_access option
          def call(opts)
            Utils::CheckHashAccessValue.call(opts, :hash_access)
            check_usage_with_delegate(opts) if opts[:hash_access]
          end

          private

          # Delegated attributes configure hash access per step with the
          # `delegate: {to_hash_access:, hash_access:}` sub-options.
          def check_usage_with_delegate(opts)
            return unless opts.key?(:delegate)

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
