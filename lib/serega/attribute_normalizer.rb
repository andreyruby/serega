# frozen_string_literal: true

class Serega
  #
  # Prepares provided attribute options
  #
  class SeregaAttributeNormalizer # :nodoc:
    # Attribute initial params
    attr_reader :init_name, :init_opts, :init_block

    # Instantiates attribute options normalizer
    def initialize(serializer_class, initials)
      @serializer_class = serializer_class
      @init_name = initials[:name]
      @init_opts = initials[:opts]
      @init_block = initials[:block]
      @method_name = nil
    end

    # Symbolized initial attribute name
    def name
      @name ||= prepare_name
    end

    # Symbolized initial attribute method name
    def method_name
      @method_name ||= prepare_method_name
    end

    # Combines all options to return single block that will be used to find
    # attribute value during serialization
    def value_block
      @value_block ||= prepare_value_block
    end

    # Detects value block parameters signature
    def value_block_signature
      @value_block_signature ||= SeregaUtils::MethodSignature.call(value_block, pos_limit: 2, keyword_args: [:ctx])
    end

    # Shows if attribute is specified to be hidden
    def hide
      return @hide if instance_variable_defined?(:@hide)

      @hide = prepare_hide
    end

    # Shows if attribute is specified to be a one-to-many relationship
    def many
      return @many if instance_variable_defined?(:@many)

      @many = prepare_many
    end

    # Shows specified attribute serializer
    def serializer
      return @serializer if instance_variable_defined?(:@serializer)

      @serializer = prepare_serializer
    end

    # Shows the default attribute value. It is a value that replaces found nils.
    #
    # When custom :default is not specified, we set empty array as default when `many: true` specified
    def default
      return @default if instance_variable_defined?(:@default)

      @default = prepare_default
    end

    # Preloads declared for this attribute, passed through as provided.
    def preloads
      return @preloads if instance_variable_defined?(:@preloads)

      @preloads = prepare_preloads
    end

    # Shows specified batch loaders names
    def batch_loaders
      @batch_loaders ||= prepare_batch_loaders
    end

    # Batch loader given directly as the :batch option. It is named after the
    # attribute and belongs to the attribute only.
    def inline_batch_loader
      batch = batch_option
      return unless batch&.inline?

      SeregaBatchLoader.new(name: name, block: batch.use)
    end

    # Callable :if, :unless, :if_value and :unless_value conditions. A Symbol
    # condition calls the method of this name.
    def conditions
      conditions = init_opts.slice(:if, :unless, :if_value, :unless_value)
      return if conditions.empty?

      conditions.transform_values do |condition|
        condition.is_a?(Symbol) ? AttributeValueResolvers::Keyword.new(condition) : condition
      end
    end

    # Formatter of the :format option. A Symbol option is the name of a
    # formatter defined with `Serega.formatter`.
    def formatter
      format = init_opts[:format]
      return unless format

      format.is_a?(Symbol) ? @serializer_class.formatters.fetch(format) : SeregaFormatters.build(format)
    end

    private

    def prepare_name
      init_name.to_sym
    end

    def prepare_value_block
      init_opts[:value] \
        || prepare_const_block \
        || prepare_delegate_block \
        || prepare_batch_loader_block \
        || prepare_keyword_block
    end

    def prepare_hide
      # Return provided directly value
      hide = init_opts[:hide]
      return hide if (hide == true) || (hide == false)

      hide_setting = config.hide_by_default
      return true if hide_setting == true
      return true if hide_setting == :auto && preload_or_batch?

      # Return nil for undefined value which means "not hide" but allows
      # to change this value by plugins
      nil
    end

    # The `hide_by_default = :auto` criterion: hide attributes that fetch extra
    # data on demand — those declared with `:preload` or an explicit `:batch`.
    #
    # This is intentionally narrower than a "goes through the batch mechanism"
    # check: a plain relation (`serializer:` without `:preload`) is
    # batch-processed too, but it only serializes an already-loaded nested
    # object, so it stays visible by default.
    def preload_or_batch?
      !!(preloads || init_opts.key?(:batch))
    end

    def config
      @serializer_class.config
    end

    def prepare_many
      init_opts[:many]
    end

    def prepare_serializer
      block = init_block
      return init_opts[:serializer] unless block

      AttributeNormalizers::Block.call(@serializer_class, name, block, init_opts[:base_serializer])
    end

    def prepare_method_name
      (init_opts[:method] || init_name).to_sym
    end

    def prepare_const_block
      return unless init_opts.key?(:const)

      AttributeValueResolvers::Const.new(init_opts[:const])
    end

    def prepare_keyword_block
      AttributeNormalizers::HashAccess.call(init_opts[:hash_access], method_name, config.hash_access)
    end

    # Reads the value from the loaded batch of the only batch loader
    def prepare_batch_loader_block
      batch = batch_option
      return unless batch

      AttributeValueResolvers::Batch.new(batch_loaders.first, batch.id || config.batch_id_option)
    end

    # Batch loader names whose loaded data this attribute's value needs. An
    # attribute without the :batch option has none.
    def prepare_batch_loaders
      batch = batch_option
      return FROZEN_EMPTY_ARRAY unless batch

      batch.loader_names
    end

    # The parsed :batch option, `nil` without it
    def batch_option
      return @batch_option if instance_variable_defined?(:@batch_option)

      batch = init_opts[:batch]
      @batch_option = batch && AttributeNormalizers::Batch.new(batch, name)
    end

    def prepare_default
      init_opts.fetch(:default) { many ? FROZEN_EMPTY_ARRAY : nil }
    end

    def prepare_delegate_block
      delegate = init_opts[:delegate]
      return unless delegate

      AttributeNormalizers::Delegate.call(delegate, method_name, config)
    end

    def prepare_preloads
      relation = !serializer.nil?
      AttributeNormalizers::Preloads.call(init_opts, relation, method_name, config)
    end
  end
end
