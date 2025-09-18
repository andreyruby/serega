# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  module AttributeValueResolvers
    #
    # Builds value resolver class for attributes with :delegate option
    #
    class DelegateResolver
      #
      # Creates resolver that delegates method call to another object
      #
      # @param delegate_to [Symbol] method to call on object to get delegated object
      # @param method_name [Symbol] method to call on delegated object
      # @param allow_nil [Boolean] whether to use safe navigation when delegated object is nil
      # @return [Delegate, DelegateAllowNil] resolver instance
      #
      def self.get(delegate_to, method_name, allow_nil)
        allow_nil ? DelegateAllowNil.new(delegate_to, method_name) : Delegate.new(delegate_to, method_name)
      end
    end

    #
    # Value resolver class for attributes with :delegate (with :allow_nil) option
    #
    class DelegateAllowNil
      def initialize(delegate_to, method_name)
        @delegate_to = delegate_to
        @method_name = method_name
      end

      #
      # Delegates method call to another object with safe navigation
      #
      # @param object [Object] the object to delegate from
      # @return [Object, nil] result of delegated method call or nil if delegated object is nil
      #
      def call(object)
        object.public_send(delegate_to)&.public_send(method_name)
      end

      private

      attr_reader :delegate_to, :method_name
    end

    #
    # Value resolver class for attributes with :delegate (without :allow_nil) option
    #
    class Delegate
      def initialize(delegate_to, method_name)
        @delegate_to = delegate_to
        @method_name = method_name
      end

      #
      # Delegates method call to another object
      #
      # @param object [Object] the object to delegate from
      # @return [Object] result of delegated method call
      #
      def call(object)
        object.public_send(@delegate_to).public_send(@method_name)
      end
    end
  end
end
