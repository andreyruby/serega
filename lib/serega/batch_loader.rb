# frozen_string_literal: true

class Serega
  #
  # Named batch loader. Loads values of many objects in one call.
  #
  # @private
  class SeregaBatchLoader
    #
    # SeregaBatchLoader instance methods
    #
    # @private
    module InstanceMethods
      # Batch loader name
      # @return [Symbol] Batch loader name
      attr_reader :name

      # Batch loader block
      # @return [#call] Batch loader block
      attr_reader :block

      #
      # Initializes new batch loader
      #
      # @param name [Symbol, String] Batch loader name
      # @param block [#call] Batch loader block
      #
      def initialize(name:, block:)
        serializer_class = self.class.serializer_class
        serializer_class::CheckBatchLoaderParams.new(name, block).validate

        @name = name.to_sym
        @block = block
        @signature = SeregaUtils::MethodSignature.call(block, pos_limit: 2, keyword_args: [:ctx])
      end

      # Loads values for objects
      # @param objects [Array] Objects to serialize
      # @param context [Hash] Serialization context
      # @return [Object] Loaded values
      def load(objects, context)
        case signature
        when "1" then block.call(objects)
        when "2" then block.call(objects, context)
        else block.call(objects, ctx: context) # "1_ctx"
        end
      end

      private

      # Batch loader block signature
      # @return [String] Batch loader block signature
      attr_reader :signature
    end

    extend SeregaHelpers::SerializerClassHelper
    include InstanceMethods
  end
end
