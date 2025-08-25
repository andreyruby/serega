# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  module AttributeValueResolvers
    #
    # Builds value resolver class for attributes with :batch option
    #
    class BatchResolver
      #
      # Generates callable block to find attribute value when attribute with :batch
      # option has no block or manual :value option.
      #
      # In other cases we should never get here as attribute value/block option must be manually defined.
      #
      # It handles this cases:
      # - `attribute :foo, batch: true`
      # - `attribute :foo, batch: FooLoader`
      # - `attribute :foo, batch: { id: :foo_id }`
      # - `attribute :foo, batch: { use: FooLoader, id: foo_id }`
      # - `attribute :foo, batch: { use: :foo_loader, id: foo_id }`
      #
      def self.get(serializer_class, attribute_name, batch_opt)
        default_method = serializer_class.config.batch_id_option

        if batch_opt == true                        # ex: `batch: true`
          batch_name = attribute_name
          batch_id_method = default_method
        elsif batch_opt.respond_to?(:call)          # ex: `batch: FooLoader`
          serializer_class.batch(attribute_name, batch_opt)
          batch_name = attribute_name
          batch_id_method = default_method
        else
          use = batch_opt[:use]
          batch_id_method = batch_opt[:id] || default_method

          if use.respond_to?(:call)                 # ex: `batch: { use: FooLoader }`
            batch_name = attribute_name
            serializer_class.batch(batch_name, use)
          else                                      # ex: `batch: { use: :foo }` || batch: { id: :some_id }
            batch_name = use || attribute_name
          end
        end

        Batch.new(batch_name, batch_id_method)
      end
    end

    #
    # Builds value resolver class for attributes with :batch option
    #
    class Batch
      attr_reader :loader_name
      attr_reader :id_method

      def initialize(loader_name, id_method)
        @loader_name = loader_name
        @id_method = id_method
      end

      # Finds object attribute value from hash of batch_loaded values
      def call(obj, batches:)
        batches.fetch(loader_name)[obj.public_send(id_method)]
      end
    end
  end
end
