# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Attribute # :nodoc:
      #
      # Attribute `:many` option validator
      #
      class CheckOptMany # :nodoc:
        class << self
          # Checks attribute :many option
          def call(opts, block = nil, required = false)
            if opts.key?(:many)
              check_many_option_makes_sence(opts, block)
              Utils::CheckOptIsBool.call(opts, :many)
            elsif required
              check_many_option_not_required(opts, block)
            end
          end

          private

          def check_many_option_not_required(opts, block)
            return if !opts[:serializer] && !block

            raise SeregaError,
              "Attribute option :many [Boolean] must be provided" \
              " for attributes with :serializer option or a block"
          end

          def check_many_option_makes_sence(opts, block)
            return if many_option_makes_sence?(opts, block)

            raise SeregaError, "Option :many can be provided only together with :serializer, :batch option or a block"
          end

          def many_option_makes_sence?(opts, block)
            opts[:serializer] || opts[:batch] || block
          end
        end
      end
    end
  end
end
