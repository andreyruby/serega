# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin :metadata
    #
    # Depends on: `:root` plugin, that must be loaded first
    #
    # Adds metadata to the serialized response via the class-level
    # `meta_attribute` method, which accepts:
    #
    # - `*path` [Array<Symbol>] - nested hash keys
    # - `**options` [Hash]
    #   - `:const` - a constant metadata value
    #   - `:value` - a `#callable` producing the metadata value
    #   - `:hide_nil` - hide the key if the value is nil (`false` by default)
    #   - `:hide_empty` - hide the key if the value is nil or empty (`false` by default)
    # - `&block` - computes the value for this meta attribute
    #
    # @example
    #  class AppSerializer < Serega
    #    plugin :root
    #    plugin :metadata
    #
    #    meta_attribute(:version, const: '1.2.3')
    #    meta_attribute(:ab_tests, :names, value: ABTests.new.method(:names))
    #    meta_attribute(:meta, :paging, hide_nil: true) do |records, ctx|
    #      next unless records.respond_to?(:total_count)
    #
    #      { page: records.page, per_page: records.per_page, total_count: records.total_count }
    #    end
    #  end
    #
    #  AppSerializer.to_h(nil) # => {:data=>nil, :version=>"1.2.3", :ab_tests=>{:names=> ... }}
    #
    module Metadata
      # @return [Symbol] Plugin name
      # @private
      def self.plugin_name
        :metadata
      end

      # Checks requirements and loads additional plugins
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param _opts [Hash] Plugin options
      #
      # @return [void]
      #
      # @private
      def self.before_load_plugin(serializer_class, **_opts)
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
        serializer_class.extend(ClassMethods)
        serializer_class.include(InstanceMethods)
        serializer_class::SeregaConfig.include(ConfigInstanceMethods)

        require_relative "meta_attribute"
        require_relative "validations/check_block"
        require_relative "validations/check_opt_const"
        require_relative "validations/check_opt_hide_nil"
        require_relative "validations/check_opt_hide_empty"
        require_relative "validations/check_opt_value"
        require_relative "validations/check_opts"
        require_relative "validations/check_path"

        meta_attribute_class = Class.new(MetaAttribute)
        meta_attribute_class.serializer_class = serializer_class
        serializer_class.const_set(:MetaAttribute, meta_attribute_class)
      end

      #
      # Adds config options and runs other callbacks after plugin was loaded
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param _opts [Hash] Plugin options
      #
      # @return [void]
      #
      # @private
      def self.after_load_plugin(serializer_class, **_opts)
        serializer_class.config.opts[:metadata] = {attribute_keys: %i[const hide_nil hide_empty value]}
      end

      #
      # Config for `metadata` plugin
      #
      class MetadataConfig
        # @return [Hash] metadata options
        attr_reader :opts

        #
        # Initializes context_metadata config object
        #
        # @param opts [Hash] options
        #
        # @return [Serega::SeregaPlugins::Metadata::MetadataConfig]
        #
        def initialize(opts)
          @opts = opts
        end

        #
        # Returns allowed metadata attribute keys
        #
        def attribute_keys
          opts.fetch(:attribute_keys)
        end
      end

      #
      # Config class additional/patched instance methods
      #
      # @see Serega::SeregaConfig
      #
      module ConfigInstanceMethods
        # @return [Serega::SeregaPlugins::Metadata::MetadataConfig] metadata config
        def metadata
          @metadata ||= MetadataConfig.new(opts.fetch(:metadata))
        end
      end

      #
      # Serega class additional/patched class methods
      #
      # @see Serega::SeregaConfig
      #
      module ClassMethods
        #
        # List of added metadata attributes
        #
        # @return [Hash<Symbol => Serega::SeregaPlugins::Metadata::MetaAttribute>] Added metadata attributes
        #
        def meta_attributes
          @meta_attributes ||= {}
        end

        #
        # Define metadata attribute
        #
        # @param path [String, Symbol] Metadata attribute path keys
        # @param opts [Hash] Metadata attribute options
        # @param block [Proc] Block to fetch metadata attribute value
        #
        # @return [Serega::SeregaPlugins::Metadata::MetaAttribute] Added metadata attribute
        #
        def meta_attribute(*path, **opts, &block)
          attribute = self::MetaAttribute.new(path: path, opts: opts, block: block)
          meta_attributes[attribute.name] = attribute
        end

        private

        def inherited(subclass)
          super

          meta_attribute_class = Class.new(self::MetaAttribute)
          meta_attribute_class.serializer_class = subclass
          subclass.const_set(:MetaAttribute, meta_attribute_class)

          # Assign same metadata attributes
          meta_attributes.each_value do |attr|
            subclass.meta_attribute(*attr.path, **attr.opts, &attr.block)
          end
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

          add_metadata(object, opts[:context], result)
          result
        end

        def add_metadata(object, context, hash)
          self.class.meta_attributes.each_value do |meta_attribute|
            metadata = meta_attribute_value(object, context, meta_attribute)
            next unless metadata

            deep_merge_metadata(hash, metadata)
          rescue => error
            raise error.exception(<<~MESSAGE.strip)
              #{error.message}
              (when serializing meta_attribute #{meta_attribute.path.inspect} in #{self.class})
            MESSAGE
          end
        end

        def meta_attribute_value(object, context, meta_attribute)
          value = meta_attribute.value(object, context)
          return if meta_attribute.hide?(value)

          # Example:
          #  [:foo, :bar].reverse_each.inject(:bazz) { |val, key| { key => val } } # => { foo: { bar: :bazz } }
          meta_attribute.path.reverse_each.inject(value) { |val, key| {key => val} }
        end

        def deep_merge_metadata(hash, metadata)
          hash.merge!(metadata) do |_key, this_val, other_val|
            if this_val.is_a?(Hash) && other_val.is_a?(Hash)
              deep_merge_metadata(this_val, other_val)
            else
              other_val
            end
          end
        end
      end
    end

    register_plugin(Metadata.plugin_name, Metadata)
  end
end
