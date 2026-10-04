# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  # @private
  module AttributeValueResolvers
    #
    # Value resolver class for attributes with :keyword option
    #
    # @private
    class Keyword
      def initialize(keyword)
        @keyword = keyword
      end

      #
      # Calls the keyword method on the object
      #
      # @param object [Object] the object to call method on
      # @return [Object] result of method call
      #
      def call(object)
        object.public_send(@keyword)
      end
    end
  end
end
