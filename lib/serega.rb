# frozen_string_literal: true

require "json"
require_relative "serega/version"

# Parent class for your serializers
class Serega
  # Frozen hash
  # @return [Hash] frozen hash
  # @private
  FROZEN_EMPTY_HASH = {}.freeze

  # Frozen array
  # @return [Array] frozen array
  # @private
  FROZEN_EMPTY_ARRAY = [].freeze

  # Locks serializers one at a time
  # @private
  LOCK_MUTEX = Mutex.new

  # Errors raised when another Ractor reads a value that is not shareable,
  # empty on a Ruby without Ractors
  # @private
  # :nocov:
  RACTOR_ISOLATION_ERRORS = (defined?(Ractor) ? [Ractor::IsolationError] : []).freeze
  # :nocov:

  # Path prefix of the Serega source files
  # @private
  LIB_PATH = File.expand_path("serega", __dir__).freeze
end

require_relative "serega/errors"
require_relative "serega/helpers/serializer_class_helper"
require_relative "serega/utils/collection_detector"
require_relative "serega/utils/enum_deep_dup"
require_relative "serega/utils/enum_deep_freeze"
require_relative "serega/utils/method_signature"
require_relative "serega/utils/ractor_local"
require_relative "serega/utils/serialized_attribute_error"
require_relative "serega/utils/to_hash"
require_relative "serega/attribute_value_resolvers/batch"
require_relative "serega/attribute_value_resolvers/const"
require_relative "serega/attribute_value_resolvers/delegate"
require_relative "serega/attribute_value_resolvers/hash_access"
require_relative "serega/attribute_value_resolvers/keyword"
require_relative "serega/attribute_values"
require_relative "serega/conditions"
require_relative "serega/formatter"
require_relative "serega/attribute"
require_relative "serega/attribute_normalizer"
require_relative "serega/engine/run"
require_relative "serega/engine/pulls"
require_relative "serega/validations/utils/check_allowed_keys"
require_relative "serega/validations/utils/check_opt_is_bool"
require_relative "serega/validations/utils/check_opt_is_hash"
require_relative "serega/validations/utils/check_opt_is_string_or_symbol"
require_relative "serega/validations/attribute/check_block"
require_relative "serega/validations/attribute/check_name"
require_relative "serega/validations/attribute/check_opt_base_serializer"
require_relative "serega/validations/attribute/check_opt_const"
require_relative "serega/validations/attribute/check_opt_hide"
require_relative "serega/validations/attribute/check_opt_if"
require_relative "serega/validations/attribute/check_opt_if_value"
require_relative "serega/validations/attribute/check_opt_delegate"
require_relative "serega/validations/attribute/check_opt_format"
require_relative "serega/validations/attribute/check_opt_batch"
require_relative "serega/validations/attribute/check_opt_hash_access"
require_relative "serega/validations/attribute/check_opt_many"
require_relative "serega/validations/attribute/check_opt_method"
require_relative "serega/validations/attribute/check_opt_preload"
require_relative "serega/validations/attribute/check_opt_serializer"
require_relative "serega/validations/attribute/check_opt_unless"
require_relative "serega/validations/attribute/check_opt_unless_value"
require_relative "serega/validations/attribute/check_opt_value"
require_relative "serega/validations/initiate/check_modifiers"
require_relative "serega/validations/check_attribute_params"
require_relative "serega/validations/check_batch_loader_params"
require_relative "serega/validations/check_formatter"
require_relative "serega/validations/check_serialize_keywords"
require_relative "serega/validations/check_serialize_params"

require_relative "serega/batch_loader"
require_relative "serega/config"
require_relative "serega/presenter"
require_relative "serega/source_group"
require_relative "serega/plan_point"
require_relative "serega/plan"
require_relative "serega/result_code"
require_relative "serega/result_builder"
require_relative "serega/plan/cache"
require_relative "serega/plugins"

class Serega
  @config = SeregaConfig.new
  @attributes = {}
  @batch_loaders = {}
  @formatters = {}
  @presenter_class = nil
  @presenter_blocks = []
  @data_classes = {}
  @struct_classes = {}

  # Validates `Serializer.attribute` params
  check_attribute_params_class = Class.new(SeregaValidations::CheckAttributeParams)
  check_attribute_params_class.serializer_class = self
  const_set(:CheckAttributeParams, check_attribute_params_class)

  # Validates `serializer#call(obj, PARAMS)` params
  check_serialize_params_class = Class.new(SeregaValidations::CheckSerializeParams)
  check_serialize_params_class.serializer_class = self
  const_set(:CheckSerializeParams, check_serialize_params_class)

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
      check_unlocked
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
    # @private
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
    # @private
    def attributes
      @attributes
    end

    #
    # Lists defined batch loaders
    #
    # @return [Hash] batch loaders list
    #
    # @private
    def batch_loaders
      @batch_loaders
    end

    #
    # Lists defined formatters
    #
    # @return [Hash<Symbol, SeregaFormatter>] Formatters by name
    #
    # @private
    def formatters
      @formatters
    end

    # Patched in:
    # - plugin :string_modifiers (returns its own cache class)
    #
    # Class of the serialization plans cache
    #
    # @return [Class<SeregaPlan::Cache>] Plans cache class
    #
    # @private
    def plan_cache_class
      SeregaPlan::Cache
    end

    #
    # Cached serialization plans
    #
    # @return [SeregaPlan::Cache, SeregaPlan::PerRactorCache] Serialization plans cache
    #
    # @private
    def plan_cache
      @plan_cache
    # :nocov:
    rescue *RACTOR_ISOLATION_ERRORS
      raise SeregaError, @unshareable_reason if @unshareable_reason

      raise SeregaError, "#{self} can not serialize in other Ractors. Call `make_shareable!` at the end of its definition"
      # :nocov:
    end

    #
    # Lists blocks given to `presenter`, in definition order
    #
    # @return [Array<Proc>] presenter blocks list
    #
    # @private
    def presenter_blocks
      @presenter_blocks
    end

    #
    # Returns (and caches) the Data class of the serialized objects with the
    # given members
    #
    # @param point_names [Array<Symbol>] Attribute names for the Data members
    # @return [Class] Subclass of Data
    #
    # @private
    def data_class_for(point_names)
      classes = @data_classes
      classes = SeregaUtils::RactorLocal.fetch(SeregaUtils::RactorLocal.key(self, :data_classes)) { {} } if classes.frozen?
      classes[point_names] ||= Data.define(*point_names)
    end

    #
    # Returns (and caches) the Struct class of the serialized objects with
    # the given members
    #
    # @param point_names [Array<Symbol>] Attribute names for the Struct members
    # @return [Class] Subclass of Struct
    #
    # @private
    def struct_class_for(point_names)
      classes = @struct_classes
      classes = SeregaUtils::RactorLocal.fetch(SeregaUtils::RactorLocal.key(self, :struct_classes)) { {} } if classes.frozen?
      classes[point_names] ||= Struct.new(*point_names)
    end

    #
    # Adds attribute
    #
    # @param name [Symbol] Attribute name. Attribute value will be found by executing `object.<name>`
    # @param opts [Hash] Options to serialize attribute
    # @param block [Proc] Defines attributes of a nested anonymous serializer.
    #   The block is executed in the context of that serializer, so everything
    #   available in a serializer class body can be used inside. The attribute
    #   value (found by name/:method/:value/:delegate/:const/:batch as usual)
    #   is serialized with this nested serializer. The nested serializer
    #   inherits from the `:base_serializer` attribute option or
    #   `config.base_serializer` (one of them is required).
    #
    # @example
    #   attribute :statistics, method: :itself do
    #     attribute :likes_count
    #     attribute :comments_count
    #   end
    #
    # @return [Serega::SeregaAttribute] Added attribute
    #
    def attribute(name, **opts, &block)
      check_unlocked
      location = caller_locations.find { |caller_location| !caller_location.path.start_with?(LIB_PATH) }
      attribute = SeregaAttribute.new(self, name: name, opts: opts, block: block, location: location && "#{location.path}:#{location.lineno}")
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
      check_unlocked
      raise SeregaError, "Batch loader must be defined with a callable value or block" if (value && block) || (!value && !block)

      batch_loader = SeregaBatchLoader.new(name: name, block: value || block)
      batch_loaders[batch_loader.name] = batch_loader
    end

    #
    # Defines a named formatter for the attribute :format option. A formatter
    # is a method name called on the value, an Array of a method name and its
    # arguments, or a callable that receives the value, and the context as a
    # second parameter or as the :ctx keyword.
    #
    # @example
    #   formatter :string, :to_s
    #   formatter :iso8601, [:iso8601, 3], allow_nil: true
    #   formatter :money, ->(cents) { cents / 100.0 }
    #
    #   attribute :created_at, format: :iso8601
    #
    # @example with block
    #   formatter(:money) { |cents, ctx| (cents / 100.0).round(ctx[:digits]) }
    #
    # @param name [Symbol] Formatter name
    # @param value [#call, Symbol, Array] Formatter
    # @param allow_nil [Boolean] Keeps nil values without formatting them
    # @param block [Proc] Formatter
    #
    # @return [SeregaFormatter] Formatter
    #
    def formatter(name, value = nil, allow_nil: false, &block)
      check_unlocked
      raise SeregaError, "Formatter name must be a Symbol" unless name.is_a?(Symbol)
      raise SeregaError, "Formatter must be defined with a value or a block" if (value && block) || (!value && !block)
      raise SeregaError, "Invalid option :allow_nil => #{allow_nil.inspect}. Must have a boolean value" unless allow_nil == true || allow_nil == false

      value ||= block
      SeregaValidations::CheckFormatter.call(name, value)
      formatters[name] = SeregaFormatter.new({use: value, allow_nil: allow_nil})
    end

    #
    # Defines presenter methods — evaluates the block inside the serializer's own
    # presenter class. Multiple blocks accumulate.
    #
    #   presenter do
    #     def name
    #       [first_name, last_name].compact.join(" ")
    #     end
    #   end
    #
    # @param block [Proc] Presenter methods
    #
    # @return [Class<SeregaPresenter>, nil] the serializer presenter class,
    #   nil when the serializer has none
    #
    def presenter(&block)
      return @presenter_class unless block

      check_unlocked
      @presenter_class ||= Class.new(SeregaPresenter)
      @presenter_class.class_exec(&block)
      presenter_blocks << block
      @presenter_class
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

      check_unlocked
      raise SeregaError, "preload_with accepts a single callable or a block, not both" if value && block

      handler = value || block
      raise SeregaError, "preload_with value must be a Proc or respond to #call" if !handler.is_a?(Proc) && !handler.respond_to?(:call)

      signature = SeregaUtils::MethodSignature.call(handler, pos_limit: 2)
      raise SeregaError, "preload_with handler must accept two positional arguments: (objects, preloads)" unless signature == "2"

      @preload_with = handler
    end

    #
    # Registers (or returns) the handler that replaces the objects to serialize
    # before serialization starts.
    #
    # The handler is called once per serialization with the objects provided to
    # `.call`/`.to_h`/`.to_data` and the serialization context. Its result is
    # serialized instead of the provided objects, which allows to accept ids or
    # other references and load the records in one place.
    #
    # The handler runs before the `:many` option is detected, so it may turn a
    # single object into a collection and back. A provided `:many` serialization
    # option is still used as is.
    #
    # The handler runs only for the objects given to the serializer, and not
    # for the objects of nested serializers.
    #
    # @example with a block
    #   prepare_initial_objects { |user_ids| User.where(id: user_ids) }
    #
    # @example with a context
    #   prepare_initial_objects { |user_ids, ctx| User.where(id: user_ids, account: ctx[:account]) }
    #
    # @example with a keyword context
    #   prepare_initial_objects { |user_ids, ctx:| User.where(id: user_ids, account: ctx[:account]) }
    #
    # @example with a callable value
    #   prepare_initial_objects UsersLoader
    #
    # @param value [#call, nil] Handler accepting (objects), (objects, context) or (objects, ctx:)
    # @param block [Proc] Handler accepting (objects), (objects, context) or (objects, ctx:)
    #
    # @return [#call, nil] The registered handler
    #
    def prepare_initial_objects(value = nil, &block)
      return @prepare_initial_objects if value.nil? && block.nil?

      check_unlocked
      raise SeregaError, "prepare_initial_objects accepts a single callable or a block, not both" if value && block

      handler = value || block
      raise SeregaError, "prepare_initial_objects value must be a Proc or respond to #call" if !handler.is_a?(Proc) && !handler.respond_to?(:call)

      signature = SeregaUtils::MethodSignature.call(handler, pos_limit: 2, keyword_args: [:ctx])
      raise SeregaError, prepare_initial_objects_signature_error unless %w[1 2 1_ctx].include?(signature)

      @prepare_initial_objects_signature = signature
      @prepare_initial_objects = handler
    end

    #
    # Signature of the registered prepare_initial_objects handler
    #
    # @return [String, nil] Handler signature
    #
    # @private
    attr_reader :prepare_initial_objects_signature

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes provided object to Hash
    #
    # @param object [Object] Object to serialize
    # @param only [Array, Hash, String, Symbol, nil] The only attributes to serialize
    # @param with [Array, Hash, String, Symbol, nil] Attributes (usually hidden) to serialize additionally
    # @param except [Array, Hash, String, Symbol, nil] Attributes to hide
    # @param check_initiate_params [Boolean, nil] Validates provided modifiers (Default is `config.check_initiate_params`)
    # @param context [Hash, nil] Serialization context
    # @param many [Boolean, nil] Set true if provided multiple objects (Default `object.is_a?(Enumerable) && !object.is_a?(Hash) && !object.is_a?(Struct)`)
    #
    # @return [Hash] Serialization result
    #
    def call(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil)
      new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
        .to_h(object, context: context, many: many)
    end

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes provided object to a tree of Ruby Data objects
    #
    # @param (see #call)
    #
    # @return [Data, Array<Data>, nil] Serialization result as Data object(s)
    #
    def to_data(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil)
      new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
        .to_data(object, context: context, many: many)
    end

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes provided object to a tree of Ruby Struct objects
    #
    # @param (see #call)
    #
    # @return [Struct, Array<Struct>, nil] Serialization result as Struct object(s)
    #
    def to_struct(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil)
      new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
        .to_struct(object, context: context, many: many)
    end

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes provided object to a JSON String: `JSON.generate` of the
    # `.to_h` result
    #
    # @param (see #call)
    #
    # @return [String] Serialization result as JSON
    #
    def to_json(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil)
      new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
        .to_json(object, context: context, many: many)
    end

    alias_method :to_h, :call

    #
    # Locks serializer definitions and config from changes.
    # Called when a serialization plan is built for the serializer.
    #
    # @return [void]
    #
    # @private
    def lock
      return if @locked

      LOCK_MUTEX.synchronize do
        next if @locked

        SeregaUtils::EnumDeepFreeze.call(config.opts)
        @locked = true
      end
    end

    #
    # Makes the serializer shareable between Ractors. Call `make_shareable!`
    # at the end of a definition to serialize in other Ractors.
    #
    # Locks the serializer and makes its definitions and its nested
    # serializers defined with blocks shareable. A serializer with a
    # definition that can not be shared serializes in the main Ractor only.
    #
    # @return [Class<Serega>] the serializer
    #
    def make_shareable!
      return self if @shareable

      lock
      attributes.each_value { |attribute| attribute.serializer.make_shareable! if attribute.initials[:block] }
      @shareable = true
      # :nocov:
      if defined?(Ractor)
        require_relative "serega/shareable"
        require_relative "serega/plan/per_ractor_cache"
        @unshareable_reason = SeregaShareable.call(self)
        @plan_cache = SeregaPlan::PerRactorCache.new(self) unless @unshareable_reason
      end
      # :nocov:
      self
    end

    #
    # Shows whether `make_shareable!` was called
    #
    # @return [Boolean] whether the serializer is shareable
    #
    def shareable?
      @shareable
    end

    private

    def check_unlocked
      raise SeregaError, "#{self} can not be changed after it was made shareable" if @shareable
      raise SeregaError, "#{self} can not be changed after it was used for serialization" if @locked
    end

    # Patched in:
    # - plugin :metadata (defines MetaAttribute and copies meta_attributes to subclasses)
    def inherited(subclass)
      config_class = Class.new(self::SeregaConfig)
      config_class.serializer_class = subclass
      subclass.const_set(:SeregaConfig, config_class)
      subclass.instance_variable_set(:@config, subclass::SeregaConfig.new(config.opts))
      subclass.instance_variable_set(:@attributes, {})
      subclass.instance_variable_set(:@batch_loaders, {})
      subclass.instance_variable_set(:@formatters, formatters.dup)
      subclass.instance_variable_set(:@presenter_class, nil)
      subclass.instance_variable_set(:@presenter_blocks, [])
      subclass.instance_variable_set(:@data_classes, {})
      subclass.instance_variable_set(:@struct_classes, {})
      subclass.instance_variable_set(:@preload_with, nil)
      subclass.instance_variable_set(:@prepare_initial_objects, nil)
      subclass.instance_variable_set(:@prepare_initial_objects_signature, nil)
      subclass.instance_variable_set(:@locked, false)
      subclass.instance_variable_set(:@shareable, false)
      subclass.instance_variable_set(:@unshareable_reason, nil)

      subclass.const_set(:SeregaAttributeValues, Class.new(self::SeregaAttributeValues))

      attribute_normalizer_class = Class.new(self::SeregaAttributeNormalizer)
      attribute_normalizer_class.serializer_class = subclass
      subclass.const_set(:SeregaAttributeNormalizer, attribute_normalizer_class)

      subclass.instance_variable_set(:@plan_cache, subclass.plan_cache_class.new(subclass))

      check_attribute_params_class = Class.new(self::CheckAttributeParams)
      check_attribute_params_class.serializer_class = subclass
      subclass.const_set(:CheckAttributeParams, check_attribute_params_class)

      check_serialize_params_class = Class.new(self::CheckSerializeParams)
      check_serialize_params_class.serializer_class = subclass
      subclass.const_set(:CheckSerializeParams, check_serialize_params_class)

      # Assign same batch loaders before the attributes that use them
      batch_loaders.each_value do |loader|
        subclass.batch(loader.name, loader.block)
      end

      # Assign same attributes
      attributes.each_value do |attr|
        subclass_attribute = SeregaAttribute.new(subclass, **attr.initials)
        subclass.attributes[subclass_attribute.name] = subclass_attribute
      end

      # Assign same preload handler
      subclass.preload_with(preload_with) if preload_with

      # Assign same initial objects handler
      subclass.prepare_initial_objects(prepare_initial_objects) if prepare_initial_objects

      # Assign same presenter blocks
      presenter_blocks.each do |presenter_block|
        subclass.presenter(&presenter_block)
      end

      super
    end

    def prepare_initial_objects_signature_error
      <<~ERR.strip
        prepare_initial_objects handler arguments should have one of this signatures:
        - (objects)        # one argument
        - (objects, ctx)   # two arguments
        - (objects, ctx:)  # one argument and one :ctx keyword argument
      ERR
    end
  end

  #
  # Serializers instance methods
  #
  module InstanceMethods
    #
    # Instantiates new Serega class
    #
    # @param only [Array, Hash, String, Symbol, nil] The only attributes to serialize
    # @param with [Array, Hash, String, Symbol, nil] Attributes (usually hidden) to serialize additionally
    # @param except [Array, Hash, String, Symbol, nil] Attributes to hide
    # @param check_initiate_params [Boolean, nil] Validates provided modifiers (Default is `config.check_initiate_params`)
    #
    def initialize(only: nil, with: nil, except: nil, check_initiate_params: nil)
      modifiers = !(only.nil? && with.nil? && except.nil?)
      check_initiate_params = config.check_initiate_params if modifiers && check_initiate_params.nil?
      @plan = self.class.plan_cache.fetch(only, with, except, check_initiate_params: modifiers && check_initiate_params)
    end

    #
    # Plan for serialization.
    # This plan can be traversed to find serialized attributes and nested attributes.
    #
    # @return [Serega::SeregaPlan] Serialization plan
    # @private
    attr_reader :plan

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes provided object to Hash
    #
    # @param object [Object] Object to serialize
    # @param context [Hash, nil] Serialization context
    # @param many [Boolean, nil] Set true if provided multiple objects (Default `object.is_a?(Enumerable) && !object.is_a?(Hash) && !object.is_a?(Struct)`)
    #
    # @return [Hash] Serialization result
    #
    def call(object, context: nil, many: nil)
      if many.equal?(false) && (builder = @plan.direct_hash_builder) && !object.nil? && (context.nil? || context.is_a?(Hash))
        return builder.call_one(object, context || FROZEN_EMPTY_HASH)
      end

      serialize_to(:hash, object, context, many, FROZEN_EMPTY_HASH)
    end

    alias_method :to_h, :call

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes provided object to Data objects
    #
    # @param (see #call)
    #
    # @return [Data] Serialization result
    #
    def to_data(object, context: nil, many: nil)
      serialize_to(:data, object, context, many, FROZEN_EMPTY_HASH)
    end

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes provided object to Struct objects
    #
    # @param (see #call)
    #
    # @return [Struct, Array<Struct>, nil] Serialization result
    #
    def to_struct(object, context: nil, many: nil)
      serialize_to(:struct, object, context, many, FROZEN_EMPTY_HASH)
    end

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes provided object to a JSON String: `JSON.generate` of the
    # `#to_h` result
    #
    # @param (see #call)
    #
    # @return [String] Serialization result as JSON
    #
    def to_json(object, context: nil, many: nil)
      JSON.generate(call(object, context: context, many: many))
    end

    private

    def config
      self.class.config
    end

    # Serializes the object with the serialization options. `opts` holds the
    # options other than :context and :many.
    def serialize_to(mode, object, context, many, opts)
      SeregaValidations::CheckSerializeKeywords.call(context, many)
      context ||= FROZEN_EMPTY_HASH
      object = prepare_objects(object, context) if self.class.prepare_initial_objects_signature
      many = SeregaUtils::CollectionDetector.call(object, @plan.collection_classes) if many.nil?
      serialize(object, opts, context, many, mode)
    end

    def prepare_objects(objects, context)
      handler = self.class.prepare_initial_objects

      case self.class.prepare_initial_objects_signature
      when "1" then handler.call(objects)
      when "2" then handler.call(objects, context)
      else handler.call(objects, ctx: context) # "1_ctx"
      end
    end

    # Patched in:
    # - plugin :root (wraps result `{ root => result }`)
    # - plugin :context_metadata (adds context metadata to final result)
    # - plugin :metadata (adds metadata to final result)
    def serialize(object, _opts, context, many, mode)
      SeregaEngine::Run.call(@plan, object, many, mode, context)
    end
  end

  extend ClassMethods
  include InstanceMethods
end
