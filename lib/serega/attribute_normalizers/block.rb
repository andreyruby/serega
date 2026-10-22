# frozen_string_literal: true

class Serega
  module AttributeNormalizers # :nodoc:
    #
    # Builds an anonymous nested serializer from the attribute block.
    #
    # The serializer is a regular subclass of an explicitly chosen base —
    # the :base_serializer attribute option or `config.base_serializer` —
    # so it inherits everything the base has: plugins, config, attributes,
    # batch loaders, the preload handler. Nested values can be any objects,
    # which is why the base is chosen explicitly instead of inheriting from
    # the current serializer. Its `inspect` is overridden to
    # `CurrentSerializer.<attribute_name>` so error messages and debugging
    # output point back to the defining attribute.
    #
    class Block # :nodoc:
      class << self
        # Builds the nested serializer of the attribute block. `base_serializer`
        # is the :base_serializer attribute option.
        #
        # Guards against cyclic definitions before building: inheriting the base
        # serializer copies its attributes, and copying a block attribute builds
        # its nested serializer — meeting the same block again while it is being
        # built means the base serializer (transitively) contains the block
        # attribute being built, so inheriting from it would recurse forever.
        # The "in progress" mark is kept on the block itself — its identity is
        # what defines the cycle (the same Proc object is shared by all copies
        # of the attribute).
        def call(serializer_class, attribute_name, block, base_serializer)
          base_serializer = chosen_base_serializer(serializer_class, base_serializer)

          if block.instance_variable_defined?(:@serega_building_nested_serializer)
            raise SeregaError,
              "Can not define a nested serializer for attribute :#{attribute_name} —" \
              " its base serializer #{base_serializer.inspect} (transitively)" \
              " contains this same block attribute (cyclic definition)"
          end

          block.instance_variable_set(:@serega_building_nested_serializer, true)
          begin
            build(serializer_class, attribute_name, block, base_serializer)
          ensure
            block.remove_instance_variable(:@serega_building_nested_serializer)
          end
        end

        private

        def build(serializer_class, attribute_name, block, base_serializer)
          label = "#{serializer_class.inspect}.<#{attribute_name}>"

          serializer = Class.new(base_serializer) do
            define_singleton_method(:inspect) { label }
            define_singleton_method(:to_s) { label }
            instance_exec(&block)
          end

          # An empty nested serializer means the block was intended as an
          # old-style value block — raise the explaining error.
          raise SeregaError, SeregaValidations::Attribute::CheckBlock::ERROR_MESSAGE if serializer.attributes.empty?

          serializer
        end

        # Base class for the nested serializer. Must be chosen explicitly —
        # usually a settings-only serializer holding plugins and configuration
        # (e.g. `config.base_serializer = self` in an application base class).
        def chosen_base_serializer(serializer_class, base_serializer)
          base_serializer ||= serializer_class.config.base_serializer
          return base_serializer if base_serializer

          raise SeregaError,
            "Attribute block requires a base serializer for the nested serializer." \
            " Provide the `base_serializer: <SerializerClass>` attribute option" \
            " or set `config.base_serializer = <SerializerClass>`"
        end
      end
    end
  end
end
