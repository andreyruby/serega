# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  module AttributeValueResolvers # :nodoc:
    #
    # Value resolver class for attributes with :keyword option
    #
    class Keyword # :nodoc:
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

      #
      # Ruby code that calls the keyword method
      #
      # @param source_variable [String] Name of the source variable in the code
      # @return [String, nil] Code, or nil when the method name is not plain
      #
      def code(source_variable)
        "#{source_variable}.#{@keyword}" if SeregaResultCode::PLAIN_METHOD_NAME.match?(@keyword)
      end
    end
  end
end
