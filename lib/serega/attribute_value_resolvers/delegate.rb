# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  module AttributeValueResolvers # :nodoc:
    #
    # Builds value resolver class for attributes with :delegate option
    #
    class DelegateResolver # :nodoc:
      # Creates resolver that delegates method call to another object
      def self.get(delegate_to, method_name, allow_nil)
        allow_nil ? DelegateAllowNil.new(delegate_to, method_name) : Delegate.new(delegate_to, method_name)
      end
    end

    #
    # Value resolver class for attributes with :delegate (with :allow_nil) option
    #
    class DelegateAllowNil < Base # :nodoc:
      def initialize(delegate_to, method_name)
        @delegate_to = delegate_to
        @method_name = method_name
      end

      # Delegates method call to another object with safe navigation
      def call(object)
        object.public_send(@delegate_to)&.public_send(@method_name)
      end

      # Ruby code that delegates the method call
      def code(source_variable)
        return unless SeregaResultCode::PLAIN_METHOD_NAME.match?(@delegate_to) && SeregaResultCode::PLAIN_METHOD_NAME.match?(@method_name)

        "#{source_variable}.#{@delegate_to}&.#{@method_name}"
      end
    end

    #
    # Value resolver class for attributes with :delegate (without :allow_nil) option
    #
    class Delegate < Base # :nodoc:
      def initialize(delegate_to, method_name)
        @delegate_to = delegate_to
        @method_name = method_name
      end

      # Delegates method call to another object
      def call(object)
        object.public_send(@delegate_to).public_send(@method_name)
      end

      # Ruby code that delegates the method call
      def code(source_variable)
        return unless SeregaResultCode::PLAIN_METHOD_NAME.match?(@delegate_to) && SeregaResultCode::PLAIN_METHOD_NAME.match?(@method_name)

        "#{source_variable}.#{@delegate_to}.#{@method_name}"
      end
    end
  end
end
