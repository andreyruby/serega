# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module Metadata
      #
      # Stores Attribute data
      #
      class MetaAttribute # :nodoc:
        # Meta attribute name
        attr_reader :name

        # Meta attribute full path
        attr_reader :path

        # Meta attribute options
        attr_reader :opts

        # Meta attribute originally added block
        attr_reader :block

        # Initializes new meta attribute
        def initialize(serializer_class, path:, opts:, block:)
          CheckParams.call(path, opts, block, serializer_class.config.check_attribute_name)

          @name = path.join(".").to_sym
          @path = SeregaUtils::EnumDeepDup.call(path)
          @opts = SeregaUtils::EnumDeepDup.call(opts)
          @block = block
          @normalized_block = normalize_block(opts[:value], opts[:const], block)
          @normalized_block_signature =
            SeregaUtils::MethodSignature.call(@normalized_block, pos_limit: 2, keyword_args: [])
        end

        # Finds attribute value
        def value(object, context)
          case normalized_block_signature
          when "0" then normalized_block.call
          when "1" then normalized_block.call(object)
          else normalized_block.call(object, context)
          end
        end

        def hide?(value)
          (!!opts[:hide_nil] && value.nil?) || (!!opts[:hide_empty] && (value.nil? || (value.respond_to?(:empty?) && value.empty?)))
        end

        private

        attr_reader :normalized_block, :normalized_block_signature

        def normalize_block(value, const, block)
          return proc { const } if const

          value || block
        end
      end
    end
  end
end
