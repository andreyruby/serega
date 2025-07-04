# frozen_string_literal: true

class Serega
  #
  # Stores serialization config
  #
  class SeregaConfig
    # :nocov: We can't use both :oj and :json adapters together

    #
    # Default config options
    #
    DEFAULTS = {
      plugins: [],
      initiate_keys: %i[only with except check_initiate_params].freeze,
      attribute_keys: %i[method value serializer many hide const delegate default preload preload_path].freeze,
      serialize_keys: %i[context many].freeze,
      check_attribute_name: true,
      check_initiate_params: true,
      delegate_default_allow_nil: false,
      max_cached_plans_per_serializer_count: 0,
      auto_preload_attributes_with_delegate: false,
      auto_preload_attributes_with_serializer: false,
      auto_hide_attributes_with_preload: false,
      to_json: (SeregaJSON.adapter == :oj) ? SeregaJSON::OjDump : SeregaJSON::JSONDump,
      from_json: (SeregaJSON.adapter == :oj) ? SeregaJSON::OjLoad : SeregaJSON::JSONLoad
    }.freeze
    # :nocov:

    # SeregaConfig Instance methods
    module SeregaConfigInstanceMethods
      #
      # Shows current config as Hash
      #
      # @return [Hash] config options
      #
      attr_reader :opts

      #
      # Initializes new config instance.
      #
      # @param opts [Hash] Initial config options
      #
      def initialize(opts = nil)
        opts ||= DEFAULTS
        @opts = SeregaUtils::EnumDeepDup.call(opts)
      end

      #
      # Shows used plugins
      #
      # @return [Array] Used plugins
      #
      def plugins
        opts.fetch(:plugins)
      end

      # Returns options names allowed in `Serega#new` method
      # @return [Array<Symbol>] allowed options keys
      def initiate_keys
        opts.fetch(:initiate_keys)
      end

      # Returns options names allowed in `Serega.attribute` method
      # @return [Array<Symbol>] Allowed options keys for attribute initialization
      def attribute_keys
        opts.fetch(:attribute_keys)
      end

      # Returns options names allowed in `to_h, to_json, as_json` methods
      # @return [Array<Symbol>] Allowed options keys for serialization
      def serialize_keys
        opts.fetch(:serialize_keys)
      end

      # Returns :check_initiate_params config option
      # @return [Boolean] Current :check_initiate_params config option
      def check_initiate_params
        opts.fetch(:check_initiate_params)
      end

      # Sets :check_initiate_params config option
      #
      # @param value [Boolean] Set :check_initiate_params config option
      #
      # @return [Boolean] :check_initiate_params config option
      def check_initiate_params=(value)
        raise SeregaError, "Must have boolean value, #{value.inspect} provided" if (value != true) && (value != false)
        opts[:check_initiate_params] = value
      end

      # Returns :delegate_default_allow_nil config option
      # @return [Boolean] Current :delegate_default_allow_nil config option
      def delegate_default_allow_nil
        opts.fetch(:delegate_default_allow_nil)
      end

      # Sets :delegate_default_allow_nil config option
      #
      # @param value [Boolean] Set :delegate_default_allow_nil config option
      #
      # @return [Boolean] :delegate_default_allow_nil config option
      def delegate_default_allow_nil=(value)
        raise SeregaError, "Must have boolean value, #{value.inspect} provided" if (value != true) && (value != false)
        opts[:delegate_default_allow_nil] = value
      end

      # Returns :max_cached_plans_per_serializer_count config option
      # @return [Boolean] Current :max_cached_plans_per_serializer_count config option
      def max_cached_plans_per_serializer_count
        opts.fetch(:max_cached_plans_per_serializer_count)
      end

      # Sets :max_cached_plans_per_serializer_count config option
      #
      # @param value [Boolean] Set :check_initiate_params config option
      #
      # @return [Boolean] New :max_cached_plans_per_serializer_count config option
      def max_cached_plans_per_serializer_count=(value)
        raise SeregaError, "Must have Integer value, #{value.inspect} provided" unless value.is_a?(Integer)
        opts[:max_cached_plans_per_serializer_count] = value
      end

      # Returns whether attributes names check is disabled
      def check_attribute_name
        opts.fetch(:check_attribute_name)
      end

      # Sets :check_attribute_name config option
      #
      # @param value [Boolean] Set :check_attribute_name config option
      #
      # @return [Boolean] New :check_attribute_name config option
      def check_attribute_name=(value)
        raise SeregaError, "Must have boolean value, #{value.inspect} provided" if (value != true) && (value != false)
        opts[:check_attribute_name] = value
      end

      # Returns current `to_json` adapter
      # @return [#call] Callable that used to construct JSON
      def to_json
        opts.fetch(:to_json)
      end

      # Sets current `to_json` adapter
      # @param value [#call] Callable that used to construct JSON
      # @return [#call] Provided callable object
      def to_json=(value)
        opts[:to_json] = value
      end

      # Returns current `from_json` adapter
      # @return [#call] Callable that used to parse JSON
      def from_json
        opts.fetch(:from_json)
      end

      # Sets current `from_json` adapter
      # @param value [#call] Callable that used to parse JSON
      # @return [#call] Provided callable object
      def from_json=(value)
        opts[:from_json] = value
      end

      # Returns :auto_preload_attributes_with_delegate config option
      # @return [Boolean] Current :auto_preload_attributes_with_delegate config option
      def auto_preload_attributes_with_delegate
        opts.fetch(:auto_preload_attributes_with_delegate)
      end

      # Sets :auto_preload_attributes_with_delegate config option
      #
      # @param value [Boolean] Set :auto_preload_attributes_with_delegate config option
      #
      # @return [Boolean] :auto_preload_attributes_with_delegate config option
      def auto_preload_attributes_with_delegate=(value)
        raise SeregaError, "Must have boolean value, #{value.inspect} provided" if (value != true) && (value != false)
        opts[:auto_preload_attributes_with_delegate] = value
      end

      # Returns :auto_preload_attributes_with_serializer config option
      # @return [Boolean] Current :auto_preload_attributes_with_serializer config option
      def auto_preload_attributes_with_serializer
        opts.fetch(:auto_preload_attributes_with_serializer)
      end

      # Sets :auto_preload_attributes_with_serializer config option
      #
      # @param value [Boolean] Set :auto_preload_attributes_with_serializer config option
      #
      # @return [Boolean] :auto_preload_attributes_with_serializer config option
      def auto_preload_attributes_with_serializer=(value)
        raise SeregaError, "Must have boolean value, #{value.inspect} provided" if (value != true) && (value != false)
        opts[:auto_preload_attributes_with_serializer] = value
      end

      # Returns :auto_hide_attributes_with_preload config option
      # @return [Boolean] Current :auto_hide_attributes_with_preload config option
      def auto_hide_attributes_with_preload
        opts.fetch(:auto_hide_attributes_with_preload)
      end

      # Sets :auto_hide_attributes_with_preload config option
      #
      # @param value [Boolean] Set :auto_hide_attributes_with_preload config option
      #
      # @return [Boolean] :auto_hide_attributes_with_preload config option
      def auto_hide_attributes_with_preload=(value)
        raise SeregaError, "Must have boolean value, #{value.inspect} provided" if (value != true) && (value != false)
        opts[:auto_hide_attributes_with_preload] = value
      end
    end

    include SeregaConfigInstanceMethods
    extend Serega::SeregaHelpers::SerializerClassHelper
  end
end
