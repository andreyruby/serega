# frozen_string_literal: true

class Serega
  # @private
  module SeregaValidations
    # @private
    module Attribute
      #
      # Attribute `:delegate` option validator
      #
      # @private
      class CheckOptDelegate
        class << self
          #
          # Checks attribute :delegate option
          # It must have :to option and can have :optional allow_nil option
          #
          # @param opts [Hash] Attribute options
          #
          # @raise [SeregaError] Attribute validation error
          #
          # @return [void]
          #
          def call(opts)
            return unless opts.key?(:delegate)

            check_opt_delegate(opts)
            check_usage_with_other_params(opts)
          end

          private

          def check_opt_delegate(opts)
            Utils::CheckOptIsHash.call(opts, :delegate)

            delegate_opts = opts[:delegate]
            check_opt_delegate_to(delegate_opts)
            check_opt_delegate_method(delegate_opts)
            check_opt_delegate_allow_nil(delegate_opts)
            check_opt_delegate_to_hash_access(delegate_opts)
            check_opt_delegate_hash_access(delegate_opts)
            check_opt_delegate_extra_opts(delegate_opts)
          end

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

          # Hash access of the intermediate (:to) step. Accepts the same
          # forms as the final (:method) step.
          def check_opt_delegate_to_hash_access(delegate_opts)
            check_hash_access_value(delegate_opts, :to_hash_access)
          end

          # Hash access of the final (:method) step. Accepts the same forms
          # as the attribute :hash_access option.
          def check_opt_delegate_hash_access(delegate_opts)
            check_hash_access_value(delegate_opts, :hash_access)
          end

          def check_hash_access_value(delegate_opts, opt_name)
            return unless delegate_opts.key?(opt_name)

            value = delegate_opts[opt_name]
            case value
            when true, false then nil
            when Symbol then check_hash_access_mode(value)
            when Hash
              Utils::CheckAllowedKeys.call(value, %i[mode allow_missing_key], opt_name)
              check_hash_access_mode(value[:mode]) if value.key?(:mode)
              Utils::CheckOptIsBool.call(value, :allow_missing_key)
            else
              raise SeregaError,
                "Invalid delegate option :#{opt_name} => #{value.inspect}." \
                " It must be a Boolean, a Symbol mode (:symbol, :string)" \
                " or a Hash with :mode and :allow_missing_key keys"
            end
          end

          def check_hash_access_mode(mode)
            return true if AttributeValueResolvers::HashAccessResolver::MODES.include?(mode)

            raise SeregaError, "Invalid :hash_access mode #{mode.inspect}. Allowed modes: :symbol, :string"
          end

          def check_opt_delegate_extra_opts(delegate_opts)
            Utils::CheckAllowedKeys.call(delegate_opts, %i[to method allow_nil to_hash_access hash_access], :delegate)
          end

          def check_usage_with_other_params(opts)
            raise SeregaError, "Option :delegate can not be used together with option :method" if opts.key?(:method)
            raise SeregaError, "Option :delegate can not be used together with option :const" if opts.key?(:const)
            raise SeregaError, "Option :delegate can not be used together with option :value" if opts.key?(:value)
            raise SeregaError, "Option :delegate can not be used together with option :batch" if opts.key?(:batch)
          end
        end
      end
    end
  end
end
