# frozen_string_literal: true

class Serega
  module SeregaPlugins
    # `plugin :context_metadata` adds metadata given per serialization with
    # the `:meta` option. Load `plugin :root` first.
    #
    # ```ruby
    # plugin :root
    # plugin :context_metadata
    #
    # UserSerializer.to_h(user, meta: {version: "1.0.1"})
    # # => {data: {username: "batman"}, version: "1.0.1"}
    # ```
    #
    # See [Metadata per serialization](https://github.com/andreyruby/serega/blob/master/docs/root-and-metadata.md#metadata-per-serialization).
    module ContextMetadata
      # Default context metadata option name
      DEFAULT_CONTEXT_METADATA_KEY = :meta # :nodoc:

      # @return [Symbol] Plugin name
      def self.plugin_name # :nodoc:
        :context_metadata
      end

      # Checks requirements and loads additional plugins
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param opts [Hash] Plugin options
      #
      # @return [void]
      def self.before_load_plugin(serializer_class, **opts) # :nodoc:
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
      def self.load_plugin(serializer_class, **_opts) # :nodoc:
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
      def self.after_load_plugin(serializer_class, **opts) # :nodoc:
        config = serializer_class.config
        meta_key = opts[:context_metadata_key] || DEFAULT_CONTEXT_METADATA_KEY
        config.opts[:context_metadata] = {key: meta_key}
        config.serialize_keys << meta_key
      end

      # Config of the `:context_metadata` plugin, `config.context_metadata`
      class ContextMetadataConfig
        # @return [Hash] context_metadata options
        attr_reader :opts # :nodoc:

        #
        # Initializes context_metadata config object
        #
        # @param opts [Hash] options
        # @param serialize_keys [Array<Symbol>] Allowed serialization options of the serializer
        #
        # @return [Serega::SeregaPlugins::ContextMetadata::ContextMetadataConfig]
        def initialize(opts, serialize_keys) # :nodoc:
          @opts = opts
          @serialize_keys = serialize_keys
        end

        # Name of the serialization option with metadata, `:meta` by default
        def key
          opts.fetch(:key)
        end

        # Sets #key. The previous name raises Serega::SeregaError.
        def key=(new_key)
          previous_key = key
          opts[:key] = new_key
          @serialize_keys.delete(previous_key)
          @serialize_keys << new_key if new_key
        end
      end

      # Config methods the plugin adds to Serega::SeregaConfig
      module ConfigInstanceMethods
        # Config of the plugin
        def context_metadata
          @plugin_configs[:context_metadata] ||= ContextMetadataConfig.new(opts.fetch(:context_metadata), serialize_keys)
        end

        # Builds the context_metadata config before freezing
        def freeze # :nodoc:
          context_metadata
          super
        end
      end

      #
      # CheckSerializeParams class additional/patched instance methods
      #
      # @see Serega::SeregaValidations::CheckSerializeParams
      #
      module CheckSerializeParamsInstanceMethods # :nodoc:
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
      module InstanceMethods # :nodoc:
        private

        def serialize(object, opts, context, many, mode)
          result = super
          return result unless result.is_a?(Hash) # return earlier if not a hash, so no root was added

          root = build_root(opts, many)
          return result unless root # return earlier when no root

          add_context_metadata(result, opts)
          result
        end

        def add_context_metadata(hash, opts)
          context_metadata_key = self.class.config.context_metadata.key
          metadata = opts[context_metadata_key]
          return unless metadata

          deep_merge_context_metadata(hash, metadata)
        end

        def deep_merge_context_metadata(hash, metadata)
          hash.merge!(metadata) { |_key, this_val, other_val| merge_context_metadata_values(this_val, other_val) }
        end

        def merge_context_metadata_values(this_val, other_val)
          return other_val unless this_val.is_a?(Hash) && other_val.is_a?(Hash)

          this_val.merge(other_val) { |_key, this_nested, other_nested| merge_context_metadata_values(this_nested, other_nested) }
        end
      end
    end

    register_plugin(ContextMetadata.plugin_name, ContextMetadata)
  end
end
