# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  module AttributeValueResolvers
    #
    # Builds value resolver class for attributes with :keyword option
    #
    class KeywordResolver
      #
      # Creates resolver that calls method on object
      #
      # @param keyword [Symbol] method name to call on object
      # @return [Keyword] resolver instance
      #
      def self.get(keyword)
        Keyword.new(keyword)
      end
    end

    #
    # Value resolver class for attributes with :keyword option
    #
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
