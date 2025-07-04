# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin `:batch`
    #
    # Must be used to omit N+1 when loading attributes values.
    #
    # @example Quick example
    #
    #   class AppSerializer
    #     plugin :batch, id_method: :id
    #   end
    #
    #   class UserSerializer < AppSerializer
    #     attribute :comments_count, batch: { loader: CommentsCountBatchLoader }, default: 0
    #     attribute :company, serializer: CompanySerializer, batch: { loader: UserCompanyBatchLoader }
    #   end
    #
    module Batch
      # Returns plugin name
      # @return [Symbol] Plugin name
      def self.plugin_name
        :batch
      end

      # Checks requirements to load plugin
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param opts [Hash] plugin options
      #
      # @return [void]
      #
      def self.before_load_plugin(serializer_class, **opts)
        allowed_keys = %i[auto_hide id_method]
        opts.each_key do |key|
          next if allowed_keys.include?(key)

          raise SeregaError,
            "Plugin #{plugin_name.inspect} does not accept the #{key.inspect} option. Allowed options:\n" \
            "  - :auto_hide [Boolean] - Marks attribute as hidden when it has :batch loader specified\n" \
            "  - :id_method [Symbol, #call] - Specified the default method to use to find object identifier"
        end
      end

      #
      # Applies plugin code to specific serializer
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param _opts [Hash] Plugin options
      #
      # @return [void]
      #
      def self.load_plugin(serializer_class, **_opts)
        require_relative "lib/batch_config"
        require_relative "lib/loader"
        require_relative "lib/loaders"
        require_relative "lib/modules/attribute"
        require_relative "lib/modules/attribute_normalizer"
        require_relative "lib/modules/check_attribute_params"
        require_relative "lib/modules/config"
        require_relative "lib/modules/object_serializer"
        require_relative "lib/modules/plan_point"
        require_relative "lib/validations/check_batch_opt_id_method"
        require_relative "lib/validations/check_batch_opt_loader"
        require_relative "lib/validations/check_opt_batch"

        serializer_class.extend(ClassMethods)
        serializer_class.include(InstanceMethods)
        serializer_class::CheckAttributeParams.include(CheckAttributeParamsInstanceMethods)
        serializer_class::SeregaAttribute.include(AttributeInstanceMethods)
        serializer_class::SeregaAttributeNormalizer.include(AttributeNormalizerInstanceMethods)
        serializer_class::SeregaPlanPoint.include(PlanPointInstanceMethods)
        serializer_class::SeregaObjectSerializer.include(SeregaObjectSerializerInstanceMethods)
      end

      #
      # Runs callbacks after plugin was attached
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param opts [Hash] Plugin options
      #
      # @return [void]
      #
      def self.after_load_plugin(serializer_class, **opts)
        serializer_class::SeregaConfig.include(ConfigInstanceMethods)

        batch_loaders_class = Class.new(SeregaBatchLoaders)
        batch_loaders_class.serializer_class = serializer_class
        serializer_class.const_set(:SeregaBatchLoaders, batch_loaders_class)

        batch_loader_class = Class.new(SeregaBatchLoader)
        batch_loader_class.serializer_class = serializer_class
        serializer_class.const_set(:SeregaBatchLoader, batch_loader_class)

        if serializer_class.plugin_used?(:activerecord_preloads)
          require_relative "lib/plugins_extensions/activerecord_preloads"
          serializer_class::SeregaBatchLoader.include(PluginsExtensions::ActiveRecordPreloads::BatchLoaderInstanceMethods)
        end

        if serializer_class.plugin_used?(:formatters)
          require_relative "lib/plugins_extensions/formatters"
          serializer_class::SeregaBatchLoader.include(PluginsExtensions::Formatters::BatchLoaderInstanceMethods)
          serializer_class::SeregaAttribute.include(PluginsExtensions::Formatters::SeregaAttributeInstanceMethods)
        end

        if serializer_class.plugin_used?(:if)
          require_relative "lib/plugins_extensions/if"
          serializer_class::SeregaObjectSerializer.include(PluginsExtensions::If::ObjectSerializerInstanceMethods123)
        end

        config = serializer_class.config
        config.attribute_keys << :batch
        config.opts[:batch] = {loaders: {}, id_method: nil, auto_hide: false}
        config.batch.auto_hide = opts[:auto_hide] if opts.key?(:auto_hide)
        config.batch.id_method = opts[:id_method] if opts.key?(:id_method)
      end

      #
      # Serega class additional/patched class methods
      #
      # @see Serega::SeregaConfig
      #
      module ClassMethods
        private

        def inherited(subclass)
          super

          batch_loaders_class = Class.new(self::SeregaBatchLoaders)
          batch_loaders_class.serializer_class = subclass
          subclass.const_set(:SeregaBatchLoaders, batch_loaders_class)

          batch_loader_class = Class.new(self::SeregaBatchLoader)
          batch_loader_class.serializer_class = subclass
          subclass.const_set(:SeregaBatchLoader, batch_loader_class)
        end
      end

      #
      # Serega additional/patched instance methods
      #
      # @see Serega::InstanceMethods
      #
      module InstanceMethods
        private

        #
        # Loads batch loaded attributes after serialization
        #
        def serialize(object, opts)
          batch_loaders = opts[:batch_loaders] = self.class::SeregaBatchLoaders.new
          result = super
          batch_loaders.load_all
          result
        end
      end
    end

    register_plugin(Batch.plugin_name, Batch)
  end
end
