# frozen_string_literal: true

class Serega
  #
  # Parsers of attribute options, used by SeregaAttributeNormalizer
  #
  module AttributeNormalizers # :nodoc:
    #
    # The attribute :batch option, parsed into the loaders and the id method.
    # `true`, a loader name, a callable or a Hash with `:use` and `:id`; `true`
    # and a Hash without `:use` use the loader named after the attribute.
    #
    class BatchOption # :nodoc:
      # Name of the attribute with the option
      attr_reader :attribute_name

      # Loader name, Array of loader names, or a callable inline loader
      attr_reader :use

      # Method that gives the id of an object, `nil` when not given
      attr_reader :id

      # Parses the :batch option of the attribute
      def initialize(batch, attribute_name)
        batch = {use: batch} unless batch.is_a?(Hash)
        use = batch.fetch(:use, true)

        @attribute_name = attribute_name
        @use = (use == true) ? attribute_name : use
        @id = batch[:id]
      end

      # Whether the option is the loader itself, a callable
      def inline?
        use.respond_to?(:call)
      end

      # Names of the batch loaders the attribute value needs. An inline loader
      # is named after the attribute.
      def loader_names
        inline? ? [attribute_name.to_sym] : Array(use).map(&:to_sym)
      end
    end
  end
end
