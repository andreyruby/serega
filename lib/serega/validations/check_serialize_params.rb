# frozen_string_literal: true

class Serega
  # @private
  module SeregaValidations
    #
    # Validations of serialization options
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
        # @param opts [Hash] serialization options
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

        def check_opts
          Utils::CheckAllowedKeys.call(opts, serializer_class.config.serialize_keys, :serialize)

          Utils::CheckOptIsHash.call(opts, :context)
          Utils::CheckOptIsBool.call(opts, :many)
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
