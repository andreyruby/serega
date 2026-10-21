# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  module AttributeValueResolvers # :nodoc:
    #
    # Value resolver class for attributes with :const option
    #
    class Const # :nodoc:
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
