# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module ExplicitManyOption
      #
      # Validator for attribute :many option
      #
      class CheckOptMany
        class << self
          #
          # Checks attribute :many option must be provided with relations
          # (attributes with the :serializer option or a block defining
          # a nested serializer)
          #
          # @param opts [Hash] Attribute options
          # @param block [nil, Proc] Attribute block
          #
          # @raise [SeregaError] Attribute validation error
          #
          # @return [void]
          #
          def call(opts, block = nil)
            return if !opts[:serializer] && !block

            many_option_exists = opts.key?(:many)
            return if many_option_exists

            raise SeregaError,
              "Attribute option :many [Boolean] must be provided" \
              " for attributes with :serializer option or a block"
          end
        end
      end
    end
  end
end
