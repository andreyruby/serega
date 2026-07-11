# frozen_string_literal: true

class Serega
  module AttributeValueResolvers
    #
    # Builds value resolver for attributes with the :hash_access option
    #
    class HashAccessResolver
      # Allowed hash access modes
      MODES = %i[symbol string].freeze

      #
      # Creates resolver that reads a key from Hash records
      #
      # @param name [Symbol, String] hash key
      # @param mode [Symbol] hash access mode (:symbol, :string)
      # @param allow_missing_key [Boolean] whether a missing key is read via `record[key]` rather than raising
      #
      # @return [HashAccessKeyword] resolver instance
      #
      def self.get(name, mode, allow_missing_key)
        HashAccessKeyword.new(name, mode, allow_missing_key)
      end
    end

    #
    # Builds value resolver for attributes with the :delegate option using
    # hash access on any of its steps
    #
    class HashAccessDelegateResolver
      #
      # Creates resolver that delegates through the provided step readers
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
    # Value resolver for attributes with the :hash_access option
    #
    class HashAccessKeyword
      def initialize(name, mode, allow_missing_key)
        @key = (mode == :symbol) ? name.to_sym : name.to_s
        @allow_missing_key = allow_missing_key
      end

      #
      # Reads the key from the record
      #
      # @param object [Object] serialized object or delegation step value
      # @return [Object] the value found
      #
      def call(object)
        return object[@key] if @allow_missing_key

        object.fetch(@key) do
          default = object[@key]
          next default unless default.nil?

          raise KeyError.new("key not found: #{@key.inspect}", key: @key, receiver: object)
        end
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
