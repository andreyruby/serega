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
      attribute_keys: %i[
        method
        value
        serializer
        many
        hide
        const
        delegate
        default
        preload
        preload_path
        batch
      ].freeze,
      serialize_keys: %i[context many].freeze,
      check_attribute_name: true,
      check_initiate_params: true,
      delegate_default_allow_nil: false,
      max_cached_plans_per_serializer_count: 0,
      auto_preload: {has_delegate_option: false, has_serializer_option: false},
      hide_by_default: false,
      batch_id_option: :id
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

      # Returns options names allowed in `call, to_h` methods
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

      # Returns :hide_by_default config option
      # @return [Boolean, Symbol] Current :hide_by_default config option
      def hide_by_default
        opts.fetch(:hide_by_default)
      end

      # Sets :hide_by_default config option
      #
      # @param value [Boolean, Symbol] Accepted values:
      #   - false (default) — nothing is hidden by default
      #   - true — all attributes are hidden by default
      #   - :auto — hides attributes that declare :preload or :batch
      #
      # @return [Boolean, Symbol] New :hide_by_default config option
      def hide_by_default=(value)
        opts[:hide_by_default] =
          case value
          when true, false, :auto
            value
          else
            raise SeregaError, "Must have true, false, or :auto, #{value.inspect} provided"
          end
      end

      # @return [Hash] auto_preload option
      def auto_preload
        opts.fetch(:auto_preload)
      end

      # Validates and sets auto_preload option
      # @return [Hash] New auto_preload option with attributes that trigger auto preload
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

      # Returns current batch_id_option
      def batch_id_option
        opts.fetch(:batch_id_option)
      end

      # Sets :batch_id_option config option
      #
      # @param value [Symbol] Set :batch_id_option config option
      #
      # @return [Symbol] New :check_attribute_name config option
      def batch_id_option=(value)
        raise SeregaError, "Must have Symbol value, #{value.inspect} provided" unless value.is_a?(Symbol)
        opts[:batch_id_option] = value
      end
    end

    include SeregaConfigInstanceMethods
    extend Serega::SeregaHelpers::SerializerClassHelper
  end
end
