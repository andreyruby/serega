# frozen_string_literal: true

class Serega
  #
  # Batch feature main module
  #
  module SeregaEngine
    #
    #  Batch loader
    #
    class Loader
      #
      # BatchLoader instance methods
      #
      module InstanceMethods
        # BatchLoader initial params
        # @return [Hash] BatchLoader initial params
        attr_reader :initials

        # BatchLoader name
        # @return [Symbol] BatchLoader name
        attr_reader :name

        # BatchLoader block
        # @return [#call] BatchLoader block
        attr_reader :block

        #
        # Initializes new batch loader
        #
        # @param name [Symbol, String] Name of attribute
        # @param block [#call] BatchLoader block
        #
        def initialize(name:, block:)
          serializer_class = self.class.serializer_class
          serializer_class::CheckBatchLoaderParams.new(name, block).validate

          @initials = SeregaUtils::EnumDeepFreeze.call(name: name, block: block)
          @name = name.to_sym
          @block = block
          @signature = SeregaUtils::MethodSignature.call(block, pos_limit: 2, keyword_args: [:ctx])
        end

        # Serializes values for objects
        # @param objects [Array] Serialized objects
        # @param context [Hash] Serialization context
        # @return [void]
        def load(objects, context)
          case signature
          when "1" then block.call(objects)
          when "2" then block.call(objects, context)
          else block.call(objects, ctx: context) # "1_ctx"
          end
        end

        private

        # BatchLoader block signature
        # @return [String] BatchLoader block signature
        attr_reader :signature
      end

      extend SeregaHelpers::SerializerClassHelper
      include InstanceMethods
    end
  end
end
