# frozen_string_literal: true

class Serega
  # Config of a serializer, `config` in a serializer class. Subclasses copy
  # the config of their parent and can change it.
  #
  # ```ruby
  # class AppSerializer < Serega
  #   config.auto_preload = true
  #   config.hide_by_default = :auto
  # end
  # ```
  #
  # See [Configuration](https://github.com/andreyruby/serega/blob/master/docs/configuration.md).
  class SeregaConfig
    # :nocov: We can't use both :oj and :json adapters together

    #
    # Default config options
    #
    DEFAULTS = { # :nodoc:
      plugins: [],
      attribute_keys: %i[
        method
        value
        serializer
        many
        hide
        const
        delegate
        default
        format
        preload
        batch
        base_serializer
        hash_access
        if
        unless
        if_value
        unless_value
      ].freeze,
      serialize_keys: %i[context many].freeze,
      check_attribute_name: true,
      require_many: false,
      check_initiate_params: true,
      delegate_default_allow_nil: false,
      max_cached_plans_per_serializer_count: 20,
      depth_limit: nil,
      auto_preload: {has_delegate_option: false, has_serializer_option: false},
      auto_preload_excluded_methods: %i[itself __getobj__].freeze,
      hide_by_default: false,
      batch_id_option: :id,
      base_serializer: nil,
      hash_access: {default_mode: :symbol, default_allow_missing_key: false}
    }.freeze
    # :nocov:

    # Config options
    module SeregaConfigInstanceMethods
      # Shows current config as Hash
      attr_reader :opts # :nodoc:

      # Initializes new config instance.
      def initialize(opts = nil) # :nodoc:
        opts ||= DEFAULTS
        @opts = SeregaUtils::EnumDeepDup.call(opts)
        @hash_access = nil
        @plugin_configs = {}
      end

      # Shows used plugins
      def plugins # :nodoc:
        opts.fetch(:plugins)
      end

      # Returns options names allowed in `Serega.attribute` method
      def attribute_keys # :nodoc:
        opts.fetch(:attribute_keys)
      end

      # Returns options names allowed in `call, to_h` methods
      def serialize_keys # :nodoc:
        opts.fetch(:serialize_keys)
      end

      # Whether unknown fields of `only:`, `except:` and `with:` raise
      # `Serega::AttributeNotExist`. `true` by default.
      def check_initiate_params
        opts.fetch(:check_initiate_params)
      end

      # Sets #check_initiate_params
      def check_initiate_params=(value)
        raise SeregaError, "Must have boolean value, #{value.inspect} provided" if (value != true) && (value != false)
        opts[:check_initiate_params] = value
      end

      # Default `allow_nil:` of the `:delegate` attribute option. `false` by
      # default.
      def delegate_default_allow_nil
        opts.fetch(:delegate_default_allow_nil)
      end

      # Sets #delegate_default_allow_nil
      def delegate_default_allow_nil=(value)
        raise SeregaError, "Must have boolean value, #{value.inspect} provided" if (value != true) && (value != false)
        opts[:delegate_default_allow_nil] = value
      end

      # Methods that #auto_preload never preloads, as they return the object
      # itself. `[:itself, :__getobj__]` by default.
      def auto_preload_excluded_methods
        opts.fetch(:auto_preload_excluded_methods)
      end

      # Sets #auto_preload_excluded_methods
      def auto_preload_excluded_methods=(value)
        unless value.is_a?(Array) && value.all?(Symbol)
          raise SeregaError, "Must be an Array of Symbols, #{value.inspect} provided"
        end

        opts[:auto_preload_excluded_methods] = value
      end

      # Parent class of nested serializers defined with an attribute block.
      # `nil` by default.
      def base_serializer
        opts.fetch(:base_serializer)
      end

      # Sets #base_serializer, a Serega subclass
      #
      # ```ruby
      # config.base_serializer = self
      # ```
      def base_serializer=(value)
        raise SeregaError, "Must be a Serega subclass, #{value.inspect} provided" if !value.is_a?(Class) || !(value <= Serega)

        opts[:base_serializer] = value
      end

      # Which attributes are hidden without the `:hide` option: `false` for none
      # (the default), `true` for all, `:auto` for attributes with preloads or
      # batch loaders.
      def hide_by_default
        opts.fetch(:hide_by_default)
      end

      # Sets #hide_by_default
      def hide_by_default=(value)
        opts[:hide_by_default] =
          case value
          when true, false, :auto
            value
          else
            raise SeregaError, "Must have true, false, or :auto, #{value.inspect} provided"
          end
      end

      # Attributes that get preloads automatically: `:delegate` attributes with
      # `has_delegate_option` and `:serializer` attributes with
      # `has_serializer_option`. Both are `false` by default.
      def auto_preload
        opts.fetch(:auto_preload)
      end

      # Sets #auto_preload: `true` or `false` for both kinds of attributes, or a
      # Hash with `has_delegate_option` and `has_serializer_option`
      def auto_preload=(value)
        opts[:auto_preload] =
          case value
          when true then {has_delegate_option: true, has_serializer_option: true}
          when false then {has_delegate_option: false, has_serializer_option: false}
          when Hash
            SeregaValidations::Utils::CheckAllowedKeys.call(value, %i[has_delegate_option has_serializer_option], "auto_preload")
            {has_delegate_option: !!value[:has_delegate_option], has_serializer_option: !!value[:has_serializer_option]}
          else
            raise SeregaError, "Must have boolean value or Hash, #{value.inspect} provided"
          end
      end

      # Builds lazy config objects before freezing, thus a frozen config
      # returns them
      def freeze # :nodoc:
        hash_access
        super
      end

      # Defaults of the `hash_access:` attribute option
      def hash_access
        @hash_access ||= HashAccessConfig.new(opts.fetch(:hash_access))
      end

      # How many serialization plans with field selection the serializer
      # caches, `20` by default. `0` disables the cache.
      def max_cached_plans_per_serializer_count
        opts.fetch(:max_cached_plans_per_serializer_count)
      end

      # Sets #max_cached_plans_per_serializer_count
      def max_cached_plans_per_serializer_count=(value)
        raise SeregaError, "Must have Integer value, #{value.inspect} provided" unless value.is_a?(Integer)
        opts[:max_cached_plans_per_serializer_count] = value
      end

      # Deepest nesting of serialized fields, `nil` for no limit (the default).
      # The limit of the serializer that starts the serialization applies.
      def depth_limit
        opts.fetch(:depth_limit)
      end

      # Sets #depth_limit: a positive Integer or `nil`
      def depth_limit=(value)
        valid = value.nil? || (value.is_a?(Integer) && value.positive?)
        raise SeregaError, "Must have positive Integer or nil value, #{value.inspect} provided" unless valid
        opts[:depth_limit] = value
      end

      # Whether attribute names may contain only `a-z`, `A-Z`, `0-9`, `_`, `-`
      # and `~`. `true` by default.
      def check_attribute_name
        opts.fetch(:check_attribute_name)
      end

      # Sets #check_attribute_name
      def check_attribute_name=(value)
        raise SeregaError, "Must have boolean value, #{value.inspect} provided" if (value != true) && (value != false)
        opts[:check_attribute_name] = value
      end

      # Whether every relation, an attribute with `:serializer` or a block,
      # must have the `:many` option. `false` by default.
      def require_many
        opts.fetch(:require_many)
      end

      # Sets #require_many
      def require_many=(value)
        raise SeregaError, "Must have boolean value, #{value.inspect} provided" if (value != true) && (value != false)
        opts[:require_many] = value
      end

      # Method that returns the id of an object for batch loaders, `:id` by
      # default
      def batch_id_option
        opts.fetch(:batch_id_option)
      end

      # Sets #batch_id_option
      def batch_id_option=(value)
        raise SeregaError, "Must have Symbol value, #{value.inspect} provided" unless value.is_a?(Symbol)
        opts[:batch_id_option] = value
      end
    end

    # Defaults of the `hash_access:` attribute option, `config.hash_access`
    class HashAccessConfig
      # hash_access config options
      attr_reader :opts # :nodoc:

      # Initializes HashAccessConfig object
      def initialize(opts) # :nodoc:
        @opts = opts
      end

      # Mode of `hash_access: true`: `:symbol` (the default) or `:string` keys
      def default_mode
        opts.fetch(:default_mode)
      end

      # Sets #default_mode
      def default_mode=(value)
        unless AttributeValueResolvers::HashAccessResolver::MODES.include?(value)
          raise SeregaError, "Invalid hash_access default_mode #{value.inspect}. Allowed modes: :symbol, :string"
        end

        opts[:default_mode] = value
      end

      # Whether a missing Hash key gives `nil` instead of raising `KeyError`.
      # `false` by default.
      def default_allow_missing_key
        opts.fetch(:default_allow_missing_key)
      end

      # Sets #default_allow_missing_key
      def default_allow_missing_key=(value)
        unless value == true || value == false
          raise SeregaError, "Invalid hash_access default_allow_missing_key #{value.inspect}. Must be a Boolean"
        end

        opts[:default_allow_missing_key] = value
      end
    end

    include SeregaConfigInstanceMethods
  end
end
