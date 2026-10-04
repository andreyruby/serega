# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  # @private
  module AttributeValueResolvers
    #
    # Value resolver class for attributes with :const option
    #
    # @private
    class Const
      def initialize(const_value)
        @const_value = const_value
      end

      #
      # Returns the constant value
      #
      # @return [Object] the constant value
      #
      def call
        @const_value
      end
    end
  end
end
