# frozen_string_literal: true

require_relative "serega/version"

# Parent class for your serializers
class Serega
  # Frozen hash
  # @return [Hash] frozen hash
  FROZEN_EMPTY_HASH = {}.freeze

  # Frozen array
  # @return [Array] frozen array
  FROZEN_EMPTY_ARRAY = [].freeze

  # Empty modifiers/serialization options (used when serializing with no opts provided)
  FROZEN_EMPTY_OPTS = [FROZEN_EMPTY_HASH, nil].freeze
  private_constant :FROZEN_EMPTY_OPTS
end

require_relative "serega/errors"
require_relative "serega/helpers/serializer_class_helper"
require_relative "serega/utils/enum_deep_dup"
require_relative "serega/utils/enum_deep_freeze"
require_relative "serega/utils/method_signature"
require_relative "serega/utils/symbol_name"
require_relative "serega/utils/to_hash"
require_relative "serega/attribute_value_resolvers/batch"
require_relative "serega/attribute_value_resolvers/const"
require_relative "serega/attribute_value_resolvers/delegate"
require_relative "serega/attribute_value_resolvers/keyword"
require_relative "serega/attribute"
require_relative "serega/attribute_normalizer"
require_relative "serega/batch/attribute_loader"
require_relative "serega/batch/attribute_loaders"
require_relative "serega/batch/loader"
require_relative "serega/validations/utils/check_allowed_keys"
require_relative "serega/validations/utils/check_opt_is_bool"
require_relative "serega/validations/utils/check_opt_is_hash"
require_relative "serega/validations/utils/check_opt_is_string_or_symbol"
require_relative "serega/validations/attribute/check_block"
require_relative "serega/validations/attribute/check_name"
require_relative "serega/validations/attribute/check_opt_const"
require_relative "serega/validations/attribute/check_opt_hide"
require_relative "serega/validations/attribute/check_opt_delegate"
require_relative "serega/validations/attribute/check_opt_batch"
require_relative "serega/validations/attribute/check_opt_many"
require_relative "serega/validations/attribute/check_opt_method"
require_relative "serega/validations/attribute/check_opt_preload"
require_relative "serega/validations/attribute/check_opt_serializer"
require_relative "serega/validations/attribute/check_opt_value"
require_relative "serega/validations/initiate/check_modifiers"
require_relative "serega/validations/check_attribute_params"
require_relative "serega/validations/check_initiate_params"
require_relative "serega/validations/check_batch_loader_params"
require_relative "serega/validations/check_serialize_params"

require_relative "serega/config"
require_relative "serega/object_serializer"
require_relative "serega/plan_point"
require_relative "serega/plan"
require_relative "serega/data_builder"
require_relative "serega/plugins"

class Serega
  @config = SeregaConfig.new

  # Validates `Serializer.attribute` params
  check_attribute_params_class = Class.new(SeregaValidations::CheckAttributeParams)
  check_attribute_params_class.serializer_class = self
  const_set(:CheckAttributeParams, check_attribute_params_class)

  # Validates `Serializer#new` params
  check_initiate_params_class = Class.new(SeregaValidations::CheckInitiateParams)
  check_initiate_params_class.serializer_class = self
  const_set(:CheckInitiateParams, check_initiate_params_class)

  # Validates `serializer#call(obj, PARAMS)` params
  check_serialize_params_class = Class.new(SeregaValidations::CheckSerializeParams)
  check_serialize_params_class.serializer_class = self
  const_set(:CheckSerializeParams, check_serialize_params_class)

  # Validates `Serializer.batch` params
  check_batch_loader_params_class = Class.new(SeregaValidations::CheckBatchLoaderParams)
  check_batch_loader_params_class.serializer_class = self
  const_set(:CheckBatchLoaderParams, check_batch_loader_params_class)

  # Assigns `SeregaBatchLoader` constant to current class
  batch_loader_class = Class.new(SeregaBatch::Loader)
  batch_loader_class.serializer_class = self
  const_set(:SeregaBatchLoader, batch_loader_class)

  # Assigns `SeregaBatchAttributeLoader` constant to current class
  batch_attribute_loader_class = Class.new(SeregaBatch::AttributeLoader)
  batch_attribute_loader_class.serializer_class = self
  const_set(:SeregaBatchAttributeLoader, batch_attribute_loader_class)

  #
  # Serializers class methods
  #
  module ClassMethods
    # Returns current config
    # @return [SeregaConfig] current serializer config
    attr_reader :config
    #
    # Enables plugin for current serializer
    #
    # @param name [Symbol, Class<Module>] Plugin name or plugin module itself
    # @param opts [Hash>] Plugin options
    #
    # @return [class<Module>] Loaded plugin module
    #
    def plugin(name, **opts)
      raise SeregaError, "This plugin is already loaded" if plugin_used?(name)

      plugin = SeregaPlugins.find_plugin(name)

      # We split loading of plugin to three parts - before_load, load, after_load:
      #
      # - **before_load_plugin** usually used to check requirements and to load additional plugins
      # - **load_plugin** usually used to include plugin modules
      # - **after_load_plugin** usually used to add config options
      plugin.before_load_plugin(self, **opts) if plugin.respond_to?(:before_load_plugin)
      plugin.load_plugin(self, **opts) if plugin.respond_to?(:load_plugin)
      plugin.after_load_plugin(self, **opts) if plugin.respond_to?(:after_load_plugin)

      # Store attached plugins, so we can check it is loaded later
      config.plugins << (plugin.respond_to?(:plugin_name) ? plugin.plugin_name : plugin)

      plugin
    end

    #
    # Checks plugin is used
    #
    # @param name [Symbol, Class<Module>] Plugin name or plugin module itself
    #
    # @return [Boolean] Is plugin used
    #
    def plugin_used?(name)
      plugin_name =
        case name
        when Module then name.respond_to?(:plugin_name) ? name.plugin_name : name
        else name
        end

      config.plugins.include?(plugin_name)
    end

    #
    # Lists attributes
    #
    # @return [Hash] attributes list
    #
    def attributes
      @attributes ||= {}
    end

    #
    # Lists defined batch loaders
    #
    # @return [Hash] batch loaders list
    #
    def batch_loaders
      @batch_loaders ||= {}
    end

    #
    # Adds attribute
    #
    # Patched in:
    # - plugin :presenter (additionally adds method in Presenter class)
    #
    # @param name [Symbol] Attribute name. Attribute value will be found by executing `object.<name>`
    # @param opts [Hash] Options to serialize attribute
    # @param block [Proc] Custom block to find attribute value. Accepts object and context.
    #
    # @return [Serega::SeregaAttribute] Added attribute
    #
    def attribute(name, **opts, &block)
      attribute = self::SeregaAttribute.new(name: name, opts: opts, block: block)
      attributes[attribute.name] = attribute
    end

    #
    # Defines a batch loader
    #
    # @example
    #   batch :tags, PostTagsLoader
    #
    # @example with block
    #   batch_loader(:tags) do |posts|
    #     Tags.where(post: posts).group(:post_id).pluck(:post_id, Arel.sql('ARRAY_AGG(tags.tag ORDER BY tag)')).to_h
    #   end
    #
    #   attribute :tags, batch: :tags, value: { |post, batch:| batch[:tags][post.id] }
    #
    # @example with context
    #   batch_loader(:tags) do |posts, ctx:|
    #     next {} if ctx[:bot]
    #
    #     Tags.where(post: posts).group(:post_id).pluck(:post_id, Arel.sql('ARRAY_AGG(tags.tag ORDER BY tag)')).to_h
    #   end
    #
    #   attribute :tags, batch: :tags, value: { |post, batch:| batch[:tags][post.id] }
    #
    # @param name [Symbol] A batch loader name
    # @param value [#call] Batch loader
    # @param block [Proc] Batch loader
    #
    # @return [#call] Batch loader
    #
    def batch(name, value = nil, &block)
      raise SeregaError, "Batch loader must be defined with a callable value or block" if (value && block) || (!value && !block)

      batch_loader = self::SeregaBatchLoader.new(name: name, block: value || block)
      batch_loaders[batch_loader.name] = batch_loader
    end

    #
    # Registers (or returns) the handler used to preload an attribute's
    # associations onto the records gathered during serialization.
    #
    # The handler is called once per preloaded attribute with the gathered
    # objects and that attribute's preloads. ORM plugins register a handler
    # that performs the actual eager loading.
    #
    # @example with a block
    #   preload_with { |objects, preloads| MyORM.eager_load(objects, preloads) }
    #
    # @example with a callable value
    #   preload_with MyPreloader
    #
    # @param value [#call, nil] Preload handler accepting two positional arguments
    # @param block [Proc] Preload handler accepting two positional arguments
    #
    # @return [#call, nil] The registered preload handler
    #
    def preload_with(value = nil, &block)
      return @preload_with if value.nil? && block.nil?
      raise SeregaError, "preload_with accepts a single callable or a block, not both" if value && block

      handler = value || block
      raise SeregaError, "preload_with value must be a Proc or respond to #call" if !handler.is_a?(Proc) && !handler.respond_to?(:call)

      signature = SeregaUtils::MethodSignature.call(handler, pos_limit: 2)
      raise SeregaError, "preload_with handler must accept two positional arguments: (objects, preloads)" unless signature == "2"

      @preload_with = handler
    end

    #
    # Serializes provided object to Hash
    #
    # @param object [Object] Serialized object
    # @param opts [Hash, nil] Serializer modifiers and other instantiating options
    # @option opts [Array, Hash, String, Symbol] :only The only attributes to serialize
    # @option opts [Array, Hash, String, Symbol] :except Attributes to hide
    # @option opts [Array, Hash, String, Symbol] :with Attributes (usually hidden) to serialize additionally
    # @option opts [Boolean] :validate Validates provided modifiers (Default is true)
    # @option opts [Hash] :context Serialization context
    # @option opts [Boolean] :many Set true if provided multiple objects (Default `object.is_a?(Enumerable)`)
    #
    # @return [Hash] Serialization result
    #
    def call(object, opts = nil)
      opts = opts&.transform_keys(&:to_sym)
      modifiers_opts = init_modifier_opts(opts)
      serialize_opts = init_serialize_opts(opts)
      new(modifiers_opts).to_h(object, serialize_opts)
    end

    #
    # Serializes provided object to a tree of Ruby Data objects
    #
    # @param object [Object] Serialized object
    # @param opts [Hash, nil] Serializer modifiers and other instantiating options
    # @option opts [Array, Hash, String, Symbol] :only The only attributes to serialize
    # @option opts [Array, Hash, String, Symbol] :except Attributes to hide
    # @option opts [Array, Hash, String, Symbol] :with Attributes (usually hidden) to serialize additionally
    # @option opts [Boolean] :validate Validates provided modifiers (Default is true)
    # @option opts [Hash] :context Serialization context
    # @option opts [Boolean] :many Set true if provided multiple objects (Default `object.is_a?(Enumerable)`)
    #
    # @return [Data, Array<Data>, nil] Serialization result as Data object(s)
    #
    def to_data(object, opts = nil)
      opts = opts&.transform_keys(&:to_sym)
      modifiers_opts = init_modifier_opts(opts)
      serialize_opts = init_serialize_opts(opts)
      new(modifiers_opts).to_data(object, serialize_opts)
    end

    alias_method :to_h, :call

    private

    def init_modifier_opts(opts)
      (!opts || opts.empty?) ? FROZEN_EMPTY_HASH : opts.slice(*config.initiate_keys)
    end

    def init_serialize_opts(opts)
      (!opts || opts.empty?) ? nil : opts.except(*config.initiate_keys)
    end

    # Patched in:
    # - plugin :metadata (defines MetaAttribute and copies meta_attributes to subclasses)
    # - plugin :presenter (defines Presenter)
    def inherited(subclass)
      config_class = Class.new(self::SeregaConfig)
      config_class.serializer_class = subclass
      subclass.const_set(:SeregaConfig, config_class)
      subclass.instance_variable_set(:@config, subclass::SeregaConfig.new(config.opts))

      attribute_class = Class.new(self::SeregaAttribute)
      attribute_class.serializer_class = subclass
      subclass.const_set(:SeregaAttribute, attribute_class)

      attribute_normalizer_class = Class.new(self::SeregaAttributeNormalizer)
      attribute_normalizer_class.serializer_class = subclass
      subclass.const_set(:SeregaAttributeNormalizer, attribute_normalizer_class)

      data_builder_class = Class.new(self::SeregaDataBuilder)
      data_builder_class.serializer_class = subclass
      subclass.const_set(:SeregaDataBuilder, data_builder_class)

      plan_class = Class.new(self::SeregaPlan)
      plan_class.serializer_class = subclass
      subclass.const_set(:SeregaPlan, plan_class)

      plan_point_class = Class.new(self::SeregaPlanPoint)
      plan_point_class.serializer_class = subclass
      subclass.const_set(:SeregaPlanPoint, plan_point_class)

      batch_loader_class = Class.new(self::SeregaBatchLoader)
      batch_loader_class.serializer_class = subclass
      subclass.const_set(:SeregaBatchLoader, batch_loader_class)

      batch_attribute_loader_class = Class.new(self::SeregaBatchAttributeLoader)
      batch_attribute_loader_class.serializer_class = subclass
      subclass.const_set(:SeregaBatchAttributeLoader, batch_attribute_loader_class)

      object_serializer_class = Class.new(self::SeregaObjectSerializer)
      object_serializer_class.serializer_class = subclass
      subclass.const_set(:SeregaObjectSerializer, object_serializer_class)

      check_attribute_params_class = Class.new(self::CheckAttributeParams)
      check_attribute_params_class.serializer_class = subclass
      subclass.const_set(:CheckAttributeParams, check_attribute_params_class)

      check_initiate_params_class = Class.new(self::CheckInitiateParams)
      check_initiate_params_class.serializer_class = subclass
      subclass.const_set(:CheckInitiateParams, check_initiate_params_class)

      check_serialize_params_class = Class.new(self::CheckSerializeParams)
      check_serialize_params_class.serializer_class = subclass
      subclass.const_set(:CheckSerializeParams, check_serialize_params_class)

      check_batch_loader_params_class = Class.new(self::CheckBatchLoaderParams)
      check_batch_loader_params_class.serializer_class = self
      subclass.const_set(:CheckBatchLoaderParams, check_batch_loader_params_class)

      # Assign same attributes
      attributes.each_value do |attr|
        params = attr.initials
        subclass.attribute(params[:name], **params[:opts], &params[:block])
      end

      # Assign same batch loaders
      batch_loaders.each_value do |loader|
        subclass.batch(loader.name, loader.block)
      end

      # Assign same preload handler
      subclass.preload_with(preload_with) if preload_with

      super
    end
  end

  #
  # Serializers instance methods
  #
  module InstanceMethods
    #
    # Instantiates new Serega class
    #
    # @param opts [Hash, nil] Serializer modifiers and other instantiating options
    # @option opts [Array, Hash, String, Symbol] :only The only attributes to serialize
    # @option opts [Array, Hash, String, Symbol] :except Attributes to hide
    # @option opts [Array, Hash, String, Symbol] :with Attributes (usually hidden) to serialize additionally
    # @option opts [Boolean] :validate Validates provided modifiers (Default is true)
    #
    def initialize(opts = nil)
      @opts =
        if opts.nil? || opts.empty?
          FROZEN_EMPTY_HASH
        else
          opts.transform_keys!(&:to_sym)
          parse_modifiers(opts)
        end

      self.class::CheckInitiateParams.new(@opts).validate if opts&.fetch(:check_initiate_params) { config.check_initiate_params }

      @plan = self.class::SeregaPlan.call(@opts)
    end

    #
    # Plan for serialization.
    # This plan can be traversed to find serialized attributes and nested attributes.
    #
    # @return [Serega::SeregaPlan] Serialization plan
    attr_reader :plan

    #
    # Serializes provided object to Hash
    #
    # @param object [Object] Serialized object
    # @param opts [Hash, nil] Serializing options
    # @option opts [Hash] :context Serialization context
    # @option opts [Boolean] :many Set true if provided multiple objects (Default `object.is_a?(Enumerable)`)
    #
    # @return [Hash] Serialization result
    #
    def call(object, opts = nil)
      opts = prepare_initial_serialization_opts(object, opts)
      serialize(object, opts)
    end

    # @see #call
    def to_h(object, opts = nil)
      call(object, opts)
    end

    #
    # Serializes provided object to Data objects
    # Patched in:
    # - plugin :root (adds a data-object for a root level keys)
    #
    # @param object [Object] Serialized object
    # @param opts [Hash, nil] Serializing options
    # @option opts [Hash] :context Serialization context
    # @option opts [Boolean] :many Set true if provided multiple objects (Default `object.is_a?(Enumerable)`)
    #
    # @return [Data] Serialization result
    #
    def to_data(object, opts = nil)
      opts = prepare_initial_serialization_opts(object, opts)
      serialized_data = serialize(object, opts)
      self.class::SeregaDataBuilder.call(self, serialized_data)
    end

    private

    attr_reader :opts

    def config
      self.class.config
    end

    def parse_modifiers(opts)
      result = {}

      opts.each do |key, value|
        value = parse_modifier(value) if (key == :only) || (key == :except) || (key == :with)
        result[key] = value
      end

      result
    end

    # Patched in:
    # - plugin :string_modifiers (parses string modifiers differently)
    def parse_modifier(value)
      SeregaUtils::ToHash.call(value)
    end

    def prepare_initial_serialization_opts(object, opts)
      opts = opts ? opts.transform_keys(&:to_sym) : {}
      self.class::CheckSerializeParams.new(opts).validate unless opts.empty?

      opts[:context] ||= {}
      opts[:batch_loaders] = SeregaBatch::AttributeLoaders.new
      opts[:many] = object.is_a?(Enumerable) unless opts.key?(:many)
      opts[:plan] = plan
      opts
    end

    # Patched in:
    # - plugin :root (wraps result `{ root => result }`)
    # - plugin :context_metadata (adds context metadata to final result)
    # - plugin :metadata (adds metadata to final result)
    def serialize(object, opts)
      result = self.class::SeregaObjectSerializer.new(**opts).serialize(object)
      opts[:batch_loaders].load_all(opts[:context])
      result
    end
  end

  extend ClassMethods
  include InstanceMethods
end
