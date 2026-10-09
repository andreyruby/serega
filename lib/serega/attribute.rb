# frozen_string_literal: true

class Serega
  #
  # Stores serialized attribute data
  #
  # @private
  class SeregaAttribute
    #
    # Attribute instance methods
    #
    # @private
    module AttributeInstanceMethods
      # Attribute initial params
      # @return [Hash] Attribute initial params
      attr_reader :initials

      # Attribute name
      # @return [Symbol] Attribute name
      attr_reader :name

      # Where the attribute is defined
      # @return [String, nil] "path:line" of the `attribute` call
      def location
        initials[:location]
      end

      # Attribute :many option
      # @return [Boolean, nil] Attribute :many option
      attr_reader :many

      # Attribute :default option
      # @return [Object, nil] Attribute :default option
      attr_reader :default

      # Attribute :hide option
      # @return [Boolean, nil] Attribute :hide option
      attr_reader :hide

      # Attribute :preloads option
      # @return [Hash, nil] Attribute :preloads option
      attr_reader :preloads

      # Batch loader names required to detect attribute value
      # @return [Array<Symbol>] Batch loader names
      attr_reader :batch_loaders

      # Attribute :if, :unless, :if_value and :unless_value conditions
      # @return [SeregaConditions, nil] Conditions, or nil without conditions
      attr_reader :conditions

      #
      # Initializes new attribute
      #
      # @param name [Symbol, String] Name of attribute
      # @param opts [Hash] Attribute options
      # @option opts [Symbol] :method Object method name to fetch attribute value
      # @option opts [Hash] :delegate Allows to fetch value from nested object
      # @option opts [Boolean] :hide Specify `true` to not serialize this attribute by default
      # @option opts [Boolean] :many Specifies has_many relationship. By default is detected via object.is_a?(Enumerable) && !object.is_a?(Hash) && !object.is_a?(Struct)
      # @option opts [Proc, #call] :value Custom block or callable to find attribute value
      # @option opts [Serega, Proc] :serializer Relationship serializer class. Use `proc { MySerializer }` if serializers have cross references
      # @param block [Proc] Defines attributes of a nested anonymous serializer
      # @param location [String, nil] Where the attribute is defined, "path:line"
      #
      def initialize(name:, opts: {}, block: nil, location: nil)
        serializer_class = self.class.serializer_class
        serializer_class::CheckAttributeParams.new(name, opts, block).validate

        @initials = SeregaUtils::EnumDeepFreeze.call(
          name: name,
          opts: SeregaUtils::EnumDeepDup.call(opts),
          block: block,
          location: location
        )

        normalizer = serializer_class::SeregaAttributeNormalizer.new(initials)
        set_normalized_vars(normalizer)
        @value_method = define_value_method(serializer_class)
      end

      # Name of the SeregaAttributeValues method that reads the value
      # @return [Symbol, nil] Method name, or nil when the value is read with #value
      attr_reader :value_method

      # @return [Boolean] Whether the attribute has an :if, :unless, :if_value or :unless_value condition
      def conditional?
        !@conditions.nil?
      end

      # Shows whether attribute has specified serializer
      # @return [Boolean] Checks if attribute is relationship (if :serializer option exists)
      def relation?
        !@serializer.nil?
      end

      # Shows specified serializer class
      # @return [Serega, nil] Attribute serializer if exists
      def serializer
        serializer = @serializer
        return serializer if (serializer.is_a?(Class) && (serializer < Serega)) || !serializer

        @serializer = serializer.is_a?(String) ? Object.const_get(serializer, false) : serializer.call
      end

      #
      # Finds attribute value
      #
      # Generated code reads plain attributes without this method, with their
      # SeregaAttributeValues method (see #value_code). A plugin that patches
      # this method must also patch #value_code to return nil.
      #
      # Patched in:
      # - plugin :formatters (formats the value)
      #
      # @param object [Object] Object to serialize
      # @param context [Hash, nil] Serialization context
      #
      # @return [Object] Serialized attribute value
      #
      def value(object, context, batches: nil)
        # Signatures should match allowed signatures in CheckOptValue
        result =
          case @value_block_signature
          when "1" then @value_block.call(object)
          when "1_ctx" then @value_block.call(object, ctx: context)
          when "1_batches" then @value_block.call(object, batches: batches)
          when "1_batches_ctx" then @value_block.call(object, ctx: context, batches: batches)
          when "2" then @value_block.call(object, context)
          when "2_batches_ctx" then @value_block.call(object, context, ctx: context, batches: batches)
          else @value_block.call # signature is "0" - no parameters
          end

        result.nil? ? @default : result
      end

      #
      # Ruby code of the SeregaAttributeValues method that reads the attribute
      # value of the source. `:const` and `:default` values come from the
      # `CONSTANTS` and `DEFAULTS` of SeregaAttributeValues.
      #
      # Patched in:
      # - plugin :formatters (formatted attributes have no code)
      #
      # @param source_variable [String] Name of the source variable in the code
      #
      # @return [String, nil] Code, or nil when the value is read with #value
      #
      def value_code(source_variable)
        code =
          case @value_block
          when AttributeValueResolvers::Keyword,
               AttributeValueResolvers::Delegate,
               AttributeValueResolvers::DelegateAllowNil
            @value_block.code(source_variable)
          when AttributeValueResolvers::Const
            "CONSTANTS[#{name.inspect}]"
          end
        return code if code.nil? || @default.nil?

        "(value = #{code}).nil? ? DEFAULTS[#{name.inspect}] : value"
      end

      #
      # Checks if attribute must be added to serialized response
      #
      # @param modifiers [Hash] Serialization modifiers
      # @option modifiers [Hash] :only The only attributes to serialize
      # @option modifiers [Hash] :except Attributes to hide
      # @option modifiers [Hash] :with Hidden attributes to serialize additionally
      #
      # @return [Boolean]
      #
      def visible?(modifiers)
        except = modifiers[:except] || FROZEN_EMPTY_HASH
        only = modifiers[:only] || FROZEN_EMPTY_HASH
        with = modifiers[:with] || FROZEN_EMPTY_HASH

        return false if except.member?(name) && except[name].empty?
        return true if only.member?(name)
        return true if with.member?(name)
        return false unless only.empty?

        !hide
      end

      private

      # Defines the SeregaAttributeValues method that reads the value of a
      # source directly. The method has the file and line of the attribute.
      # A name of a BasicObject method, for example `initialize`, gets no
      # method.
      def define_value_method(serializer_class)
        code = value_code("source")
        return unless code
        return if ::BasicObject.method_defined?(name) || ::BasicObject.private_method_defined?(name)

        values_class = serializer_class::SeregaAttributeValues
        values_class::CONSTANTS[name] = @value_block.call if @value_block.is_a?(AttributeValueResolvers::Const)
        values_class::DEFAULTS[name] = @default unless @default.nil?

        file, _, line = location ? location.rpartition(":") : ["(attribute #{name})", nil, "1"]
        method_code =
          if SeregaResultCode::PLAIN_METHOD_NAME.match?(name)
            "def #{name}(source) = #{code}"
          else
            "define_method(#{name.inspect}) { |source| #{code} }"
          end

        values_class.class_eval(method_code, file, line.to_i)
        name
      end

      def set_normalized_vars(normalizer)
        @name = normalizer.name
        @many = normalizer.many
        @default = normalizer.default
        @value_block = normalizer.value_block
        @value_block_signature = normalizer.value_block_signature
        @hide = normalizer.hide
        @serializer = normalizer.serializer
        @preloads = normalizer.preloads
        @batch_loaders = normalizer.batch_loaders
        conditions = normalizer.conditions
        @conditions = conditions && SeregaConditions.new(self, conditions)
      end
    end

    extend Serega::SeregaHelpers::SerializerClassHelper
    include AttributeInstanceMethods
  end
end
