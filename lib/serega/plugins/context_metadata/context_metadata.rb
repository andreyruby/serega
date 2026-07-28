# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin :context_metadata
    #
    # Depends on: `:root` plugin, that must be loaded first
    #
    # Adds metadata supplied per serialization call (as opposed to `:metadata`,
    # which is defined statically on the serializer).
    #
    # @example
    #   class UserSerializer < Serega
    #     plugin :root, root: :data
    #     plugin :context_metadata, context_metadata_key: :meta
    #   end
    #
    #   UserSerializer.to_h(nil, meta: { version: '1.0.1' })
    #   # => {:data=>nil, :version=>"1.0.1"}
    #
    module ContextMetadata
      # Default context metadata option name
      DEFAULT_CONTEXT_METADATA_KEY = :meta

      # @return [Symbol] Plugin name
      # @private
      def self.plugin_name
        :context_metadata
      end

      # Checks requirements and loads additional plugins
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param opts [Hash] Plugin options
      #
      # @return [void]
      #
      # @private
      def self.before_load_plugin(serializer_class, **opts)
        allowed_keys = %i[context_metadata_key]
        opts.each_key do |key|
          next if allowed_keys.include?(key)

          raise SeregaError,
            "Plugin #{plugin_name.inspect} does not accept the #{key.inspect} option. Allowed options:\n" \
            "  - :context_metadata_key [Symbol] - The key name that must be used to add metadata. Default is :meta."
        end

        unless serializer_class.plugin_used?(:root)
          raise SeregaError, "Plugin #{plugin_name.inspect} must be loaded after the :root plugin. Please load the :root plugin first"
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
      # @private
      def self.load_plugin(serializer_class, **_opts)
        serializer_class.include(InstanceMethods)
        serializer_class::SeregaConfig.include(ConfigInstanceMethods)
        serializer_class::CheckSerializeParams.include(CheckSerializeParamsInstanceMethods)
      end

      #
      # Adds config options and runs other callbacks after plugin was loaded
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param opts [Hash] Plugin options
      #
      # @return [void]
      #
      # @private
      def self.after_load_plugin(serializer_class, **opts)
        config = serializer_class.config
        meta_key = opts[:context_metadata_key] || DEFAULT_CONTEXT_METADATA_KEY
        config.opts[:context_metadata] = {key: meta_key}
        config.serialize_keys << meta_key
      end

      #
      # Config for `context_metadata` plugin
      #
      class ContextMetadataConfig
        # @return [Hash] context_metadata options
        attr_reader :opts

        #
        # Initializes context_metadata config object
        #
        # @param opts [Hash] options
        #
        # @return [Serega::SeregaPlugins::ContextMetadata::ContextMetadataConfig]
        def initialize(opts)
          @opts = opts
        end

        # Key that should be used to define metadata
        def key
          opts.fetch(:key)
        end

        # Sets key that should be used to define metadata
        #
        # @param new_key [Symbol] New key
        #
        # @return [Symbol] New key
        def key=(new_key)
          opts[:key] = new_key
        end
      end

      #
      # Config class additional/patched instance methods
      #
      # @see Serega::SeregaConfig
      #
      module ConfigInstanceMethods
        # @return [Serega::SeregaPlugins::ContextMetadata::ContextMetadataConfig] context_metadata config
        def context_metadata
          @context_metadata ||= ContextMetadataConfig.new(opts.fetch(:context_metadata))
        end
      end

      #
      # CheckSerializeParams class additional/patched instance methods
      #
      # @see Serega::SeregaValidations::CheckSerializeParams
      #
      # @private
      module CheckSerializeParamsInstanceMethods
        private

        def check_opts
          super

          meta_key = self.class.serializer_class.config.context_metadata.key
          SeregaValidations::Utils::CheckOptIsHash.call(opts, meta_key)
        end
      end

      #
      # Serega additional/patched instance methods
      #
      # @see Serega
      #
      # @private
      module InstanceMethods
        private

        def serialize(object, opts)
          result = super
          return result unless result.is_a?(Hash) # return earlier if not a hash, so no root was added

          root = build_root(object, opts)
          return result unless root # return earlier when no root

          add_context_metadata(result, opts)
          result
        end

        def add_context_metadata(hash, opts)
          context_metadata_key = self.class.config.context_metadata.key
          return unless context_metadata_key

          metadata = opts[context_metadata_key]
          return unless metadata

          deep_merge_context_metadata(hash, metadata)
        end

        def deep_merge_context_metadata(hash, metadata)
          hash.merge!(metadata) do |_key, this_val, other_val|
            if this_val.is_a?(Hash) && other_val.is_a?(Hash)
              deep_merge_context_metadata(this_val, other_val)
            else
              other_val
            end
          end
        end
      end
    end

    register_plugin(ContextMetadata.plugin_name, ContextMetadata)
  end
end
