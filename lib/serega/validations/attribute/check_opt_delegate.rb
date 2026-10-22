# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Attribute # :nodoc:
      #
      # Attribute `:delegate` option validator
      #
      class CheckOptDelegate # :nodoc:
        class << self
          # Checks attribute :delegate option
          # It must have :to option and can have :optional allow_nil option
          def call(opts)
            return unless opts.key?(:delegate)

            Utils::CheckOptIsHash.call(opts, :delegate)

            delegate_opts = opts[:delegate]
            check_opt_delegate_to(delegate_opts)
            check_opt_delegate_method(delegate_opts)
            check_opt_delegate_allow_nil(delegate_opts)
            check_opt_delegate_hash_access(delegate_opts)
            check_opt_delegate_extra_opts(delegate_opts)
          end

          private

          def check_opt_delegate_to(delegate_opts)
            to_exist = delegate_opts.key?(:to)
            raise SeregaError, "Option :delegate must have a :to option" unless to_exist

            Utils::CheckOptIsStringOrSymbol.call(delegate_opts, :to)
          end

          def check_opt_delegate_method(delegate_opts)
            Utils::CheckOptIsStringOrSymbol.call(delegate_opts, :method)
          end

          # Covers only the intermediate object being nil — a missing key on
          # either step is each step's own :allow_missing_key sub-option.
          def check_opt_delegate_allow_nil(delegate_opts)
            Utils::CheckOptIsBool.call(delegate_opts, :allow_nil)
          end

          # Hash access of the intermediate (:to) step and of the final
          # (:method) step. Both accept the forms of the attribute :hash_access
          # option.
          def check_opt_delegate_hash_access(delegate_opts)
            Utils::CheckHashAccessValue.call(delegate_opts, :to_hash_access)
            Utils::CheckHashAccessValue.call(delegate_opts, :hash_access)
          end

          def check_opt_delegate_extra_opts(delegate_opts)
            Utils::CheckAllowedKeys.call(delegate_opts, %i[to method allow_nil to_hash_access hash_access], :delegate)
          end
        end
      end
    end
  end
end
