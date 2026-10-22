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

      # Adds the plugin to the serializer
      def self.apply(serializer_class, **opts) # :nodoc:
        SeregaValidations::Utils::CheckAllowedKeys.call(opts, %i[context_metadata_key], "plugin :context_metadata")

        unless serializer_class.plugin_used?(:root)
          raise SeregaError, "Plugin :context_metadata must be loaded after the :root plugin. Please load the :root plugin first"
        end

        serializer_class.include(InstanceMethods)
        serializer_class::SeregaConfig.include(ConfigInstanceMethods)

        config = serializer_class.config
        meta_key = opts[:context_metadata_key] || DEFAULT_CONTEXT_METADATA_KEY
        config.opts[:context_metadata] = {key: meta_key}
        config.serialize_keys << meta_key
      end

      # Config of the `:context_metadata` plugin, `config.context_metadata`
      class ContextMetadataConfig
        # context_metadata options
        attr_reader :opts # :nodoc:

        # Initializes context_metadata config object
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

      # Serega additional/patched instance methods
      module InstanceMethods # :nodoc:
        private

        def checked_opts(opts)
          checked_opts = super
          SeregaValidations::Utils::CheckOptIsHash.call(checked_opts, self.class.config.context_metadata.key)
          checked_opts
        end

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
  end
end
