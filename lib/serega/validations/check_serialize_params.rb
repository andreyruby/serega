# frozen_string_literal: true

class Serega
  # @private
  module SeregaValidations
    #
    # Validations of the serialization options other than :context and
    # :many. CheckSerializeKeywords checks :context and :many.
    #
    # @private
    class CheckSerializeParams
      #
      # Validations of serialization options instance methods
      #
      # @private
      module InstanceMethods
        attr_reader :opts

        #
        # Initializes validator for serialization options
        #
        # @param opts [Hash] serialization options other than :context and :many
        #
        # @return [void]
        #
        def initialize(opts)
          @opts = opts
        end

        #
        # Validates serialization options
        #
        def validate
          check_opts
        end

        private

        # Patched in:
        # - plugin :context_metadata (checks the context metadata is a Hash)
        def check_opts
          Utils::CheckAllowedKeys.call(opts, serializer_class.config.serialize_keys, :serialize)
        end

        def serializer_class
          self.class.serializer_class
        end
      end

      include InstanceMethods
      extend Serega::SeregaHelpers::SerializerClassHelper
    end
  end
end
