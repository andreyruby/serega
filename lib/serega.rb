# frozen_string_literal: true

require "json"
require_relative "serega/version"

# Parent class of serializers. A serializer lists attributes and serializes
# objects to Hashes, JSON, Data or Struct objects:
#
# ```ruby
# class UserSerializer < Serega
#   attribute :first_name
#   attribute :email, hide: true
# end
#
# UserSerializer.to_h(user)                # => {first_name: "Bruce"}
# UserSerializer.to_h(user, with: :email)  # => {first_name: "Bruce", email: "bruce@wayne.com"}
# ```
#
# See the [guides](https://github.com/andreyruby/serega/blob/master/docs/README.md).
class Serega
  # Frozen hash
  FROZEN_EMPTY_HASH = {}.freeze # :nodoc:

  # Frozen array
  FROZEN_EMPTY_ARRAY = [].freeze # :nodoc:

  # Locks serializers one at a time
  LOCK_MUTEX = Mutex.new # :nodoc:

  # Errors raised when another Ractor reads a value that is not shareable,
  # empty on a Ruby without Ractors
  # :nocov:
  RACTOR_ISOLATION_ERRORS = (defined?(Ractor) ? [Ractor::IsolationError] : []).freeze # :nodoc:
  # :nocov:

  # Path prefix of the Serega source files
  LIB_PATH = File.expand_path("serega", __dir__).freeze # :nodoc:
end

require_relative "serega/errors"
require_relative "serega/utils/collection_detector"
require_relative "serega/utils/enum_deep_dup"
require_relative "serega/utils/enum_deep_freeze"
require_relative "serega/utils/method_signature"
require_relative "serega/utils/parse_string_modifiers"
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
require_relative "serega/attribute_normalizers/batch"
require_relative "serega/attribute_normalizers/block"
require_relative "serega/attribute_normalizers/delegate"
require_relative "serega/attribute_normalizers/hash_access"
require_relative "serega/attribute_normalizers/preloads"
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

  #
  # Class methods of serializers: they define attributes and serialize
  #
  module ClassMethods
    # Config of the serializer. Subclasses copy it.
    #
    # ```ruby
    # config.hide_by_default = true
    # ```
    #
    # See [Configuration](https://github.com/andreyruby/serega/blob/master/docs/configuration.md).
    attr_reader :config

    #
    # Turns on a built-in feature by name, with its options. Subclasses get it
    # too.
    #
    # ```ruby
    # plugin :root, root_one: :user, root_many: :users
    # ```
    #
    # See [Root Key and Metadata](https://github.com/andreyruby/serega/blob/master/docs/root-and-metadata.md).
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

    # Checks plugin is used
    def plugin_used?(name) # :nodoc:
      plugin_name =
        case name
        when Module then name.respond_to?(:plugin_name) ? name.plugin_name : name
        else name
        end

      config.plugins.include?(plugin_name)
    end

    #
    # Attributes by name, hidden and inherited ones too
    #
    # ```ruby
    # UserSerializer.attributes.keys # => [:first_name, :email]
    # ```
    #
    def attributes
      @attributes
    end

    # Lists defined batch loaders
    def batch_loaders # :nodoc:
      @batch_loaders
    end

    # Lists defined formatters
    def formatters # :nodoc:
      @formatters
    end

    # Cached serialization plans
    def plan_cache # :nodoc:
      @plan_cache
    # :nocov:
    rescue *RACTOR_ISOLATION_ERRORS
      raise SeregaError, @unshareable_reason if @unshareable_reason

      raise SeregaError, "#{self} can not serialize in other Ractors. Call `make_shareable!` at the end of its definition"
      # :nocov:
    end

    # Lists blocks given to `presenter`, in definition order
    def presenter_blocks # :nodoc:
      @presenter_blocks
    end

    # Returns (and caches) the Data class of the serialized objects with the
    # given members
    def data_class_for(point_names) # :nodoc:
      classes = @data_classes
      classes = SeregaUtils::RactorLocal.fetch(SeregaUtils::RactorLocal.key(self, :data_classes)) { {} } if classes.frozen?
      classes[point_names] ||= Data.define(*point_names)
    end

    # Returns (and caches) the Struct class of the serialized objects with
    # the given members
    def struct_class_for(point_names) # :nodoc:
      classes = @struct_classes
      classes = SeregaUtils::RactorLocal.fetch(SeregaUtils::RactorLocal.key(self, :struct_classes)) { {} } if classes.frozen?
      classes[point_names] ||= Struct.new(*point_names)
    end

    #
    # Adds an attribute. By default its value is `object.<name>`, and the
    # options change that:
    #
    # ```ruby
    # attribute :first_name
    # attribute :name, method: :full_name
    # attribute :email, hide: true
    # attribute :posts, serializer: PostSerializer
    # ```
    #
    # A block defines the attributes of a nested serializer. It inherits from
    # the `:base_serializer` option or `config.base_serializer`:
    #
    # ```ruby
    # attribute :statistics, method: :itself do
    #   attribute :likes_count
    #   attribute :comments_count
    # end
    # ```
    #
    # See [Attributes](https://github.com/andreyruby/serega/blob/master/docs/attributes.md#all-options)
    # for all options.
    #
    def attribute(name, **opts, &block)
      check_unlocked
      location = caller_locations.find { |caller_location| !caller_location.path.start_with?(LIB_PATH) }
      attribute = SeregaAttribute.new(self, name: name, opts: opts, block: block, location: location && "#{location.path}:#{location.lineno}")
      attributes[attribute.name] = attribute
    end

    #
    # Defines a named batch loader: a callable or a block that receives the
    # objects, and the context as a second parameter or as the `:ctx`
    # keyword. It returns the values by object id. Subclasses inherit it.
    #
    # ```ruby
    # batch :likes_count, ->(users) { Like.where(user: users).group(:user_id).count }
    # batch(:rank) { |users, ctx:| Rank.for(users, ctx[:season]) }
    #
    # attribute :likes_count, batch: true
    # ```
    #
    # See [Batch loading](https://github.com/andreyruby/serega/blob/master/docs/batch-loading.md).
    #
    def batch(name, value = nil, &block)
      check_unlocked
      raise SeregaError, "Batch loader must be defined with a callable value or block" if (value && block) || (!value && !block)

      batch_loader = SeregaBatchLoader.new(name: name, block: value || block)
      batch_loaders[batch_loader.name] = batch_loader
    end

    #
    # Defines a named formatter for the `:format` attribute option. A formatter
    # is a method name called on the value, an Array of a method name and its
    # arguments, or a callable or a block that receives the value, and the
    # context as a second parameter or as the `:ctx` keyword. With
    # `allow_nil: true` a `nil` value stays `nil`. Subclasses inherit it.
    #
    # ```ruby
    # formatter :string, :to_s
    # formatter :iso8601, [:iso8601, 3]
    # formatter(:money) { |cents, ctx| "#{cents / 100.0} #{ctx[:currency]}" }
    #
    # attribute :created_at, format: :iso8601
    # ```
    #
    # See [Formatters](https://github.com/andreyruby/serega/blob/master/docs/formatters.md).
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
    # Defines presenter methods: attributes read their values from them. The
    # block runs in the presenter class of the serializer, and each call adds
    # methods. Returns the presenter class, `nil` without one.
    #
    # ```ruby
    # attribute :name
    #
    # presenter do
    #   def name
    #     [first_name, last_name].compact.join(" ")
    #   end
    # end
    # ```
    #
    # See [Presenter](https://github.com/andreyruby/serega/blob/master/docs/presenter.md).
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
    # Sets the handler that preloads the `:preload` value of an attribute. It
    # runs once per attribute with a preload, with the objects to serialize
    # and the preloads. Without arguments, returns the handler. Subclasses
    # inherit it.
    #
    # ```ruby
    # preload_with { |objects, preloads| RecordPreloader.call(objects, preloads) }
    # preload_with AppPreloader
    # ```
    #
    # See [Preloads](https://github.com/andreyruby/serega/blob/master/docs/preloads.md).
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
    # Sets the handler that replaces the objects given to the serializer, for
    # example ids with records. It runs once per serialization, before Serega
    # detects a list, and receives the objects, and the context as a second
    # parameter or as the `:ctx` keyword. Objects of relations skip it.
    # Without arguments, returns the handler.
    #
    # ```ruby
    # prepare_initial_objects { |user_ids| User.where(id: user_ids) }
    # prepare_initial_objects { |ids, ctx:| User.where(id: ids, account: ctx[:account]) }
    # prepare_initial_objects UsersLoader
    # ```
    #
    # See [Prepare initial objects](https://github.com/andreyruby/serega/blob/master/docs/prepare-initial-objects.md).
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

    # Signature of the registered prepare_initial_objects handler
    attr_reader :prepare_initial_objects_signature # :nodoc:

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes an object or a list to a Hash or an Array of Hashes. `nil`
    # serializes to `nil`.
    #
    # - `only`, `except`, `with`: fields to serialize, to skip and to add,
    #   see [Selecting fields](https://github.com/andreyruby/serega/blob/master/docs/selecting-fields.md);
    # - `check_initiate_params`: `false` skips unknown fields, by default
    #   `config.check_initiate_params`;
    # - `context`: data for attribute values and conditions;
    # - `many`: `true` serializes a list, `false` one object. By default an
    #   `Enumerable` that is not a `Hash` or `Struct` is a list.
    #
    # ```ruby
    # UserSerializer.to_h(user)                     # => {first_name: "Bruce"}
    # UserSerializer.to_h([user], with: :email)     # => [{first_name: "Bruce", email: "bruce@wayne.com"}]
    # UserSerializer.to_h(user, context: {admin: true})
    # ```
    #
    # See [Serializing](https://github.com/andreyruby/serega/blob/master/docs/serializing.md).
    #
    def call(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil)
      new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
        .to_h(object, context: context, many: many)
    end

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes like #to_h, to `Data` objects
    #
    # ```ruby
    # UserSerializer.to_data(user) # => #<data first_name="Bruce">
    # ```
    #
    def to_data(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil)
      new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
        .to_data(object, context: context, many: many)
    end

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes like #to_h, to `Struct` objects
    #
    # ```ruby
    # UserSerializer.to_struct(user) # => #<struct first_name="Bruce">
    # ```
    #
    def to_struct(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil)
      new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
        .to_struct(object, context: context, many: many)
    end

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes like #to_h, to a JSON String: `JSON.generate` of the #to_h
    # result
    #
    # ```ruby
    # UserSerializer.to_json(user) # => "{\"first_name\":\"Bruce\"}"
    # ```
    #
    def to_json(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil)
      new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
        .to_json(object, context: context, many: many)
    end

    alias_method :to_h, :call

    # Locks serializer definitions and config from changes.
    # Called when a serialization plan is built for the serializer.
    def lock # :nodoc:
      return if @locked

      LOCK_MUTEX.synchronize do
        next if @locked

        SeregaUtils::EnumDeepFreeze.call(config.opts)
        @locked = true
      end
    end

    #
    # Makes the serializer shareable between Ractors. Call it at the end of a
    # definition to serialize in other Ractors. It locks the serializer and
    # its nested serializers defined with blocks. A serializer with a
    # definition that can not be shared serializes in the main Ractor only.
    #
    # ```ruby
    # class UserSerializer < Serega
    #   attribute :first_name
    #
    #   make_shareable!
    # end
    # ```
    #
    # See [Ractors](https://github.com/andreyruby/serega/blob/master/docs/ractors.md).
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

    # Shows whether `make_shareable!` was called
    def shareable? # :nodoc:
      @shareable
    end

    private

    def check_unlocked
      raise SeregaError, "#{self} can not be changed after it was made shareable" if @shareable
      raise SeregaError, "#{self} can not be changed after it was used for serialization" if @locked
    end

    # Patched in:
    # - plugin :metadata (copies meta_attributes to subclasses)
    def inherited(subclass)
      subclass.const_set(:SeregaConfig, Class.new(self::SeregaConfig))
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

      subclass.instance_variable_set(:@plan_cache, SeregaPlan::Cache.new(subclass))

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
  # Instance methods of serializers. An instance keeps its field selection
  # and serializes many times.
  #
  module InstanceMethods
    #
    # Prepares a serializer with a field selection. The options are the field
    # options of Serega::ClassMethods#to_h.
    #
    # ```ruby
    # serializer = UserSerializer.new(only: [:first_name])
    # serializer.to_h(user)  # => {first_name: "Bruce"}
    # serializer.to_h(users) # => [{first_name: "Bruce"}, {first_name: "Alfred"}]
    # ```
    #
    def initialize(only: nil, with: nil, except: nil, check_initiate_params: nil)
      modifiers = !(only.nil? && with.nil? && except.nil?)
      check_initiate_params = config.check_initiate_params if modifiers && check_initiate_params.nil?
      @plan = self.class.plan_cache.fetch(only, with, except, check_initiate_params: modifiers && check_initiate_params)
    end

    # Plan for serialization.
    # This plan can be traversed to find serialized attributes and nested attributes.
    attr_reader :plan # :nodoc:

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes an object or a list to a Hash or an Array of Hashes, with the
    # serialization options of Serega::ClassMethods#to_h
    #
    # ```ruby
    # UserSerializer.new.to_h(user, context: {admin: true})
    # ```
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
    # Serializes like #to_h, to `Data` objects
    #
    def to_data(object, context: nil, many: nil)
      serialize_to(:data, object, context, many, FROZEN_EMPTY_HASH)
    end

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes like #to_h, to `Struct` objects
    #
    def to_struct(object, context: nil, many: nil)
      serialize_to(:struct, object, context, many, FROZEN_EMPTY_HASH)
    end

    # Patched in:
    # - plugin :root (takes the options of plugins)

    #
    # Serializes like #to_h, to a JSON String: `JSON.generate` of the #to_h
    # result
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
