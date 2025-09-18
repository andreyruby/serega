# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  module AttributeValueResolvers
    #
    # Builds value resolver class for attributes with :const option
    #
    class ConstResolver
      #
      # Creates resolver that returns constant value
      #
      # @param const_value [Object] constant value to return
      # @return [Const] resolver instance
      #
      def self.get(const_value)
        Const.new(const_value)
      end
    end

    #
    # Value resolver class for attributes with :const option
    #
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
