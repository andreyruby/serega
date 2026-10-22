# frozen_string_literal: true

class Serega
  module SeregaPlugins
    # `plugin :metadata` adds metadata defined with
    # Serega::SeregaPlugins::Metadata::ClassMethods#meta_attribute. Load
    # `plugin :root` first.
    #
    # ```ruby
    # plugin :root
    # plugin :metadata
    #
    # meta_attribute :version, const: "1.2.3"
    # ```
    #
    # See [Metadata](https://github.com/andreyruby/serega/blob/master/docs/root-and-metadata.md#metadata).
    module Metadata
      # Adds the plugin to the serializer
      def self.apply(serializer_class, **_opts) # :nodoc:
        unless serializer_class.plugin_used?(:root)
          raise SeregaError, "Plugin :metadata must be loaded after the :root plugin. Please load the :root plugin first"
        end

        require_relative "meta_attribute"
        require_relative "check_params"

        serializer_class.extend(ClassMethods)
        serializer_class.include(InstanceMethods)
        serializer_class.instance_variable_set(:@meta_attributes, {})
      end

      # Class methods the plugin adds to serializers
      module ClassMethods
        # List of added metadata attributes
        def meta_attributes # :nodoc:
          @meta_attributes
        end

        # Adds metadata under a path of keys. The value is `const:`, a `value:`
        # callable or a block, which receive the serialized objects and the
        # context. `hide_nil: true` skips `nil` values, `hide_empty: true` skips
        # `nil` and empty values.
        #
        # ```ruby
        # meta_attribute :meta, :paging, hide_nil: true do |records, ctx|
        #   next unless records.respond_to?(:total_count)
        #
        #   {page: records.current_page, total_count: records.total_count}
        # end
        # ```
        def meta_attribute(*path, **opts, &block)
          check_unlocked
          attribute = MetaAttribute.new(self, path: path, opts: opts, block: block)
          meta_attributes[attribute.name] = attribute
        end

        private

        def inherited(subclass)
          super

          subclass.instance_variable_set(:@meta_attributes, {})

          # Assign same metadata attributes
          meta_attributes.each_value do |attr|
            subclass.meta_attribute(*attr.path, **attr.opts, &attr.block)
          end
        end
      end

      # Serega additional/patched instance methods
      module InstanceMethods # :nodoc:
        private

        def serialize(object, opts, context, many, mode)
          result = super
          return result unless result.is_a?(Hash) # return earlier if not a hash, so no root was added

          root = build_root(opts, many)
          return result unless root # return earlier when no root

          add_metadata(object, context, result)
          result
        end

        def add_metadata(object, context, hash)
          self.class.meta_attributes.each_value do |meta_attribute|
            metadata = meta_attribute_value(object, context, meta_attribute)
            next unless metadata

            SeregaUtils::DeepMerge.call(hash, metadata)
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

          # Example: path [:foo, :bar] and value :bazz give { foo: { bar: :bazz } }
          meta_attribute.path.reverse_each { |key| value = {key => value} }
          value
        end
      end
    end
  end
end
