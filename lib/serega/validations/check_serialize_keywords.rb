# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    #
    # Validator for the :context and :many serialization options
    #
    class CheckSerializeKeywords # :nodoc:
      class << self
        #
        # Checks the context is a Hash and many is a boolean, when given
        #
        # @param context [Hash, nil] Serialization context
        # @param many [Boolean, nil] Whether the object is a collection
        #
        # @raise [SeregaError] Serialization option validation error
        #
        # @return [void]
        #
        def call(context, many)
          unless context.nil? || context.is_a?(Hash)
            raise SeregaError, "Invalid option :context => #{context.inspect}. Must have a Hash value"
          end

          return if many.nil? || many.equal?(true) || many.equal?(false)

          raise SeregaError, "Invalid option :many => #{many.inspect}. Must have a boolean value"
        end
      end
    end
  end
end
