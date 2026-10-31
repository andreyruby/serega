# frozen_string_literal: true

class Serega
  module AttributeValueResolvers # :nodoc:
    #
    # Settings of the :hash_access option
    #
    class HashAccessResolver # :nodoc:
      # Allowed hash access modes
      MODES = %i[symbol string].freeze
    end

    #
    # Builds value resolver for attributes with the :delegate option using
    # hash access on any of its steps
    #
    class HashAccessDelegateResolver # :nodoc:
      # Creates resolver that delegates through the provided step readers
      def self.get(to_step, final_step, delegate_allow_nil)
        delegate_allow_nil ? HashAccessDelegateAllowNil.new(to_step, final_step) : HashAccessDelegate.new(to_step, final_step)
      end
    end

    #
    # Value resolver for attributes with the :hash_access option
    #
    class HashAccessKeyword # :nodoc:
      def initialize(name, mode, allow_missing_key)
        @key = (mode == :symbol) ? name.to_sym : name.to_s
        @allow_missing_key = allow_missing_key
      end

      # Reads the key from the record
      def call(object)
        return object[@key] if @allow_missing_key

        object.fetch(@key) do
          default = object[@key]
          default.nil? ? object.fetch(@key) : default
        end
      end

      # Ruby code that reads the key, the same way as #call
      def code(source_variable)
        key = SeregaUtils::RubyLiteral.code(@key)
        return "#{source_variable}[#{key}]" if @allow_missing_key

        "#{source_variable}.fetch(#{key}) { (found = #{source_variable}[#{key}]).nil? ? #{source_variable}.fetch(#{key}) : found }"
      end
    end

    #
    # Value resolver for attributes with :hash_access and :delegate (without :allow_nil) options
    #
    class HashAccessDelegate # :nodoc:
      def initialize(to_step, final_step)
        @to_step = to_step
        @final_step = final_step
      end

      # Delegates the value reading through the intermediate object
      def call(object)
        @final_step.call(@to_step.call(object))
      end

      # Ruby code that delegates the value reading, the same way as #call
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
    class HashAccessDelegateAllowNil # :nodoc:
      def initialize(to_step, final_step)
        @to_step = to_step
        @final_step = final_step
      end

      # Delegates the value reading through the intermediate object,
      # resolving a nil intermediate to nil
      def call(object)
        intermediate = @to_step.call(object)
        return if intermediate.nil?

        @final_step.call(intermediate)
      end

      # Ruby code that delegates the value reading, the same way as #call
      def code(source_variable)
        to_code = @to_step.code(source_variable)
        final_code = @final_step.code("intermediate")
        return unless to_code && final_code

        "((intermediate = #{to_code}).nil? ? nil : #{final_code})"
      end
    end
  end
end
