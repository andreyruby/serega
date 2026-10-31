# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  module AttributeValueResolvers # :nodoc:
    #
    # Value resolver class for attributes with :const option
    #
    class Const < Base # :nodoc:
      def initialize(const_value)
        @const_value = const_value
      end

      # Returns the constant value
      def call
        @const_value
      end

      # The value is the `:const` option
      def const?
        true
      end
    end
  end
end
