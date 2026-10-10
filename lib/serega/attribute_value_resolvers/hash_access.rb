# frozen_string_literal: true

class Serega
  # @private
  module AttributeValueResolvers
    #
    # Settings of the :hash_access option
    #
    # @private
    class HashAccessResolver
      # Allowed hash access modes
      MODES = %i[symbol string].freeze
    end

    #
    # Builds value resolver for attributes with the :delegate option using
    # hash access on any of its steps
    #
    # @private
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
    # @private
    class HashAccessKeyword
      def initialize(name, mode, allow_missing_key)
        @key = (mode == :symbol) ? name.to_sym : name.to_s
        @allow_missing_key = allow_missing_key
      end

      #
      # Reads the key from the record
      #
      # @param object [Object] object to serialize or delegation step value
      # @return [Object] the value found
      #
      def call(object)
        return object[@key] if @allow_missing_key

        object.fetch(@key) do
          default = object[@key]
          default.nil? ? object.fetch(@key) : default
        end
      end

      #
      # Ruby code that reads the key, the same way as #call
      #
      # @param source_variable [String] Name of the source variable in the code
      # @return [String] Code
      #
      def code(source_variable)
        key = @key.is_a?(String) ? "#{@key.inspect}.freeze" : @key.inspect
        return "#{source_variable}[#{key}]" if @allow_missing_key

        "#{source_variable}.fetch(#{key}) { (found = #{source_variable}[#{key}]).nil? ? #{source_variable}.fetch(#{key}) : found }"
      end
    end

    #
    # Value resolver for attributes with :hash_access and :delegate (without :allow_nil) options
    #
    # @private
    class HashAccessDelegate
      def initialize(to_step, final_step)
        @to_step = to_step
        @final_step = final_step
      end

      #
      # Delegates the value reading through the intermediate object
      #
      # @param object [Object] object to serialize
      # @return [Object] the value found
      #
      def call(object)
        @final_step.call(@to_step.call(object))
      end

      #
      # Ruby code that delegates the value reading, the same way as #call
      #
      # @param source_variable [String] Name of the source variable in the code
      # @return [String, nil] Code, or nil when a step has no code
      #
      def code(source_variable)
        to_code = @to_step.code(source_variable)
        final_code = @final_step.code("intermediate")
        return unless to_code && final_code

        "(intermediate = #{to_code}; #{final_code})"
      end
    end

    #
    # Value resolver for attributes with :hash_access and :delegate (with :allow_nil) options
    #
    # @private
    class HashAccessDelegateAllowNil
      def initialize(to_step, final_step)
        @to_step = to_step
        @final_step = final_step
      end

      #
      # Delegates the value reading through the intermediate object,
      # resolving a nil intermediate to nil
      #
      # @param object [Object] object to serialize
      # @return [Object, nil] the value found
      #
      def call(object)
        intermediate = @to_step.call(object)
        return if intermediate.nil?

        @final_step.call(intermediate)
      end

      #
      # Ruby code that delegates the value reading, the same way as #call
      #
      # @param source_variable [String] Name of the source variable in the code
      # @return [String, nil] Code, or nil when a step has no code
      #
      def code(source_variable)
        to_code = @to_step.code(source_variable)
        final_code = @final_step.code("intermediate")
        return unless to_code && final_code

        "((intermediate = #{to_code}).nil? ? nil : #{final_code})"
      end
    end
  end
end
