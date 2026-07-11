# frozen_string_literal: true

class Serega
  module AttributeValueResolvers
    #
    # Builds value resolver for attributes with the :hash_access option
    #
    class HashAccessResolver
      # Allowed hash access modes
      MODES = %i[symbol string auto].freeze

      #
      # Creates resolver that reads a key from Hash records and calls
      # a method on everything else
      #
      # @param name [Symbol, String] attribute method name or hash key
      # @param mode [Symbol] hash access mode (:symbol, :string, :auto)
      # @param allow_nil [Boolean] whether a missing key resolves to nil instead of raising
      #
      # @return [HashAccessKeyword] resolver instance
      #
      def self.get(name, mode, allow_nil)
        HashAccessKeyword.new(name, mode, allow_nil)
      end
    end

    #
    # Builds value resolver for attributes with the :delegate option using
    # hash access on any of its steps
    #
    class HashAccessDelegateResolver
      #
      # Creates resolver that delegates through the provided step readers.
      # A step is a hash-aware reader (HashAccessKeyword) or a plain method
      # reader (Keyword) — each hash-aware step re-checks whether its object
      # is a Hash, so mixed chains (a hash holding objects, an object holding
      # hashes) work.
      #
      # @param to_step [#call] reader of the intermediate object
      # @param final_step [#call] reader of the final value
      # @param delegate_allow_nil [Boolean] whether a nil intermediate object resolves to nil
      #
      # @return [HashAccessDelegate, HashAccessDelegateAllowNil] resolver instance
      #
      def self.get(to_step, final_step, delegate_allow_nil)
        delegate_allow_nil ? HashAccessDelegateAllowNil.new(to_step, final_step) : HashAccessDelegate.new(to_step, final_step)
      end
    end

    #
    # Value resolver for attributes with the :hash_access option.
    # Reads a key from Hash records (according to the mode) and calls a public
    # method on everything else. Also used as one step of a delegation chain.
    #
    class HashAccessKeyword
      def initialize(name, mode, allow_nil)
        @method_name = name.to_sym
        @symbol_key = name.to_sym
        @string_key = name.to_s
        @key = (mode == :string) ? @string_key : @symbol_key
        @auto = (mode == :auto)
        @allow_nil = allow_nil
      end

      #
      # Reads the value from a Hash record by key or from any other object
      # by calling the public method
      #
      # @param object [Object] serialized object or delegation step value
      # @return [Object] the value found
      #
      def call(object)
        return read_object(object) unless object.is_a?(Hash)
        return read_auto(object) if @auto
        return object[@key] if @allow_nil

        object.fetch(@key) { raise SeregaError, "Hash has no #{@key.inspect} key" }
      end

      private

      # In :auto mode with allow_nil, a non-Hash object missing the method
      # resolves to nil — same leniency as a hash missing the key, so mixed
      # hash/object data with optional fields serializes uniformly. All other
      # combinations keep the plain method call (a missing method raises).
      def read_object(object)
        return nil if @auto && @allow_nil && !object.respond_to?(@method_name)

        object.public_send(@method_name)
      end

      def read_auto(hash)
        return hash[@symbol_key] if hash.key?(@symbol_key)
        return hash[@string_key] if hash.key?(@string_key)
        return hash.public_send(@method_name) if hash.respond_to?(@method_name)
        return nil if @allow_nil

        raise SeregaError, "Hash has no #{@symbol_key.inspect} or #{@string_key.inspect} key and no ##{@method_name} method"
      end
    end

    #
    # Value resolver for attributes with :hash_access and :delegate (without :allow_nil) options
    #
    class HashAccessDelegate
      def initialize(to_step, final_step)
        @to_step = to_step
        @final_step = final_step
      end

      #
      # Delegates the value reading through the intermediate object
      #
      # @param object [Object] serialized object
      # @return [Object] the value found
      #
      def call(object)
        @final_step.call(@to_step.call(object))
      end
    end

    #
    # Value resolver for attributes with :hash_access and :delegate (with :allow_nil) options
    #
    class HashAccessDelegateAllowNil
      def initialize(to_step, final_step)
        @to_step = to_step
        @final_step = final_step
      end

      #
      # Delegates the value reading through the intermediate object,
      # resolving a nil intermediate to nil
      #
      # @param object [Object] serialized object
      # @return [Object, nil] the value found
      #
      def call(object)
        intermediate = @to_step.call(object)
        return if intermediate.nil?

        @final_step.call(intermediate)
      end
    end
  end
end
