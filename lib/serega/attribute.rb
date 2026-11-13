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
      @value_callable = @value_block.is_a?(AttributeValueResolvers::Callable) ? @value_block.callable : nil
      @hide = normalizer.hide
      serializer = normalizer.serializer
      @serializer = serializer && SerializerReference.new(serializer)
      @preloads = normalizer.preloads
      @batch_loaders = normalizer.batch_loaders
      @inline_batch_loader = normalizer.inline_batch_loader
      @formatter = normalizer.formatter
      @value_code = ValueCode.new(@name, @value_block, @default, @formatter)
      conditions = normalizer.conditions
      @conditions = conditions && SeregaConditions.new(self, conditions)
      store_values(serializer_class)
      @reads_presenter = false
    end

    # Method of the serialized object that gives the value, `nil` for a value
    # from :value, :const, :delegate, :hash_access or :batch
    def object_method
      @value_block.object_method if resolver?
    end

    # Ruby code that reads the value in generated code
    attr_reader :value_code

    # The :value callable, nil without the :value option
    attr_reader :value_callable

    # Methods that reading the value and checking the :if and :unless
    # conditions call on the object, nil when a callable or a batch loader
    # gets the object
    def source_methods
      return unless resolver?

      methods = @value_block.source_methods
      return methods unless methods && @conditions

      condition_methods = @conditions.source_methods
      condition_methods && (methods + condition_methods)
    end

    # Notes whether the attribute reads the object through the presenter: it
    # calls a presenter method, or it gives the object to a callable or a
    # batch loader. The serializer calls it when it is locked, because
    # presenter methods can be added after the attribute.
    def check_presenter(presenter_class)
      methods = source_methods
      @reads_presenter = methods.nil? || presenter_class.presents_any?(methods)
    end

    # Whether the attribute reads the object through the presenter, known
    # after the serializer is locked
    def reads_presenter?
      @reads_presenter
    end

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
    # Generated code reads plain attributes and :value callables without
    # this method, with their #value_code.
    def value(object, context, batches: nil)
      result =
        case @value_block_signature
        when "1" then @value_block.call(object) # resolvers that read the object
        when "1_batches" then @value_block.call(object, batches: batches) # the Batch resolver
        when "1_batches_ctx" then @value_block.call(object, ctx: context, batches: batches) # Callable
        else @value_block.call # the Const resolver
        end

      result = @default if result.nil?
      @formatter ? @formatter.call(result, context) : result
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

    # Stores the values of the attribute that generated code reads in the
    # SeregaAttributeValues of the serializer: the `:const` and `:default`
    # values and the formatter
    def store_values(serializer_class)
      values_class = serializer_class::SeregaAttributeValues
      values_class::CONSTANTS[name] = @value_block.call if resolver? && @value_block.const?
      values_class::DEFAULTS[name] = @default unless @default.nil?
      values_class::FORMATTERS[name] = @formatter.callable if @formatter&.callable
      values_class::FORMATTER_ARGS[name] = @formatter.args if @formatter&.args
    end
  end
end
