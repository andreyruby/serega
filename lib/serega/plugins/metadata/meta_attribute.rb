# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module Metadata
      #
      # Stores Attribute data
      #
      # @private
      class MetaAttribute
        #
        # Stores Attribute instance methods
        #
        # @private
        module InstanceMethods
          # @return [Symbol] Meta attribute name
          attr_reader :name

          # @return [Symbol] Meta attribute full path
          attr_reader :path

          # @return [Proc] Meta attribute options
          attr_reader :opts

          # @return [Proc,nil] Meta attribute originally added block
          attr_reader :block

          #
          # Initializes new meta attribute
          #
          # @param path [Array<Symbol, String>] Path for metadata of attribute
          #
          # @param opts [Hash] metadata attribute options
          #
          # @param block [Proc] Proc that receives object(s) and context and finds value
          #
          def initialize(path:, opts:, block:)
            check(path, opts, block)

            @name = path.join(".").to_sym
            @path = SeregaUtils::EnumDeepDup.call(path)
            @opts = SeregaUtils::EnumDeepDup.call(opts)
            @block = block
            @normalized_block = normalize_block(opts[:value], opts[:const], block)
            @normalized_block_signature =
              SeregaUtils::MethodSignature.call(@normalized_block, pos_limit: 2, keyword_args: [])
          end

          #
          # Finds attribute value
          #
          # @param object [Object] Serialized object(s)
          # @param context [Hash, nil] Serialization context
          #
          # @return [Object] Serialized meta attribute value
          #
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

          def check(path, opts, block)
            CheckPath.call(path) if check_attribute_name
            CheckOpts.call(opts, block, attribute_keys)
            CheckBlock.call(block) if block
          end

          def attribute_keys
            self.class.serializer_class.config.metadata.attribute_keys
          end

          def check_attribute_name
            self.class.serializer_class.config.check_attribute_name
          end
        end

        extend Serega::SeregaHelpers::SerializerClassHelper
        include InstanceMethods
      end
    end
  end
end
