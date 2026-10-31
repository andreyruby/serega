# frozen_string_literal: true

class Serega
  #
  # Stores serialized attribute data
  #
  class SeregaAttribute # :nodoc:
    # Serializer of the attribute
    attr_reader :serializer_class

    # Attribute initial params
    attr_reader :initials

    # Attribute name
    attr_reader :name

    # Where the attribute is defined
    def location
      initials[:location]
    end

    # Attribute :many option
    attr_reader :many

    # Attribute :default option
    attr_reader :default

    # Attribute :hide option
    attr_reader :hide

    # Attribute :preloads option
    attr_reader :preloads

    # Batch loader names required to detect attribute value
    attr_reader :batch_loaders

    # Batch loader given directly as the :batch option
    attr_reader :inline_batch_loader

    # Attribute :if, :unless, :if_value and :unless_value conditions
    attr_reader :conditions

    # Initializes new attribute
    def initialize(serializer_class, name:, opts: {}, block: nil, location: nil)
      SeregaValidations::CheckAttributeParams.new(serializer_class, name, opts, block).validate

      @serializer_class = serializer_class
      @initials = SeregaUtils::EnumDeepFreeze.call(
        name: name,
        opts: SeregaUtils::EnumDeepDup.call(opts),
        block: block,
        location: location
      )

      normalizer = SeregaAttributeNormalizer.new(serializer_class, initials)
      @name = normalizer.name
      @many = normalizer.many
      @default = normalizer.default
      @value_block = normalizer.value_block
      @value_block_signature = normalizer.value_block_signature
      @hide = normalizer.hide
      serializer = normalizer.serializer
      @serializer = serializer && SerializerReference.new(serializer)
      @preloads = normalizer.preloads
      @batch_loaders = normalizer.batch_loaders
      @inline_batch_loader = normalizer.inline_batch_loader
      @formatter = normalizer.formatter
      conditions = normalizer.conditions
      @conditions = conditions && SeregaConditions.new(self, conditions)
      @value_method = define_value_method(serializer_class)
    end

    # Method of the serialized object that gives the value, `nil` for a value
    # from :value, :const, :delegate, :hash_access or :batch
    def object_method
      @value_block.object_method if resolver?
    end

    # Name of the SeregaAttributeValues method that reads the value
    attr_reader :value_method

    # Whether the attribute has an :if, :unless, :if_value or :unless_value condition
    def conditional?
      !@conditions.nil?
    end

    # Shows whether attribute has specified serializer
    def relation?
      !@serializer.nil?
    end

    # Serializer class of the :serializer option or the block, nil without
    # a relation
    def serializer
      @serializer&.resolve
    end

    # Finds attribute value
    #
    # Generated code reads plain attributes without this method, with
    # their #value_code.
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

      result = @default if result.nil?
      @formatter ? @formatter.call(result, context) : result
    end

    # Ruby code that reads the attribute value of the source. `:const` and
    # `:default` values and formatters come from the `CONSTANTS`,
    # `DEFAULTS`, `FORMATTERS` and `FORMATTER_ARGS` of SeregaAttributeValues.
    def value_code(source_variable, constants_prefix = "")
      return unless resolver?

      resolver = @value_block
      code = resolver.const? ? "#{constants_prefix}CONSTANTS[#{name.inspect}]" : resolver.code(source_variable)
      return unless code

      code = "(value = #{code}).nil? ? #{constants_prefix}DEFAULTS[#{name.inspect}] : value" unless @default.nil?
      return code unless @formatter

      @formatter.code(code, "#{constants_prefix}FORMATTERS[#{name.inspect}]", "#{constants_prefix}FORMATTER_ARGS[#{name.inspect}]")
    end

    # Defines the methods of the code on the owner, at the file and line of
    # the attribute, thus their backtraces point to the attribute
    def define_methods(owner, code)
      file, _, line = location ? location.rpartition(":") : ["(attribute #{name})", nil, "1"]
      owner.class_eval(code, file, line.to_i)
    end

    private

    # Whether the value comes from a resolver that Serega built from the
    # options, and not from a `:value` callable of the user
    def resolver?
      @value_block.is_a?(AttributeValueResolvers::Base)
    end

    # Defines the SeregaAttributeValues method that reads the value of a
    # source directly, for example `read_full_name`. The method has the
    # file and line of the attribute.
    def define_value_method(serializer_class)
      code = value_code("source")
      return unless code

      values_class = serializer_class::SeregaAttributeValues
      values_class::CONSTANTS[name] = @value_block.call if @value_block.const?
      values_class::DEFAULTS[name] = @default unless @default.nil?
      values_class::FORMATTERS[name] = @formatter.callable if @formatter&.callable
      values_class::FORMATTER_ARGS[name] = @formatter.args if @formatter&.args

      method_name = value_method_name(values_class)
      define_methods(values_class, "def #{method_name}(source) = #{code}")
      method_name
    end

    # Plain method name of the attribute, for example `read_first_name` for
    # `first-name`. The name keeps a final `?` or `!`. A name taken by
    # another attribute gets a number, for example `read_first_name_2`. The
    # same attribute keeps its name.
    def value_method_name(values_class)
      method_names = values_class::METHOD_NAMES
      method_name = method_names[name]
      return method_name if method_name

      base, mark = name.to_s.match(/\A(.*?)([?!]?)\z/).captures
      base = "read_#{base.gsub(/\W/, "_")}"
      method_name = :"#{base}#{mark}"
      number = 1
      while method_names.value?(method_name)
        number += 1
        method_name = :"#{base}_#{number}#{mark}"
      end
      method_names[name] = method_name
    end
  end
end
