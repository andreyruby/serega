# frozen_string_literal: true

class Serega
  module SeregaBatch
    #
    # Factory generates callable object that should be able to take
    # batch loaded results, current object, and find attribute value for this
    # object
    #
    class AutoResolverFactory
      #
      # Generates callable block to find attribute value when attribute with :batch
      # option has no block or manual :value option.
      #
      # It handles this cases:
      # - `attribute :foo, batch: true`
      # - `attribute :foo, batch: FooLoader`
      # - `attribute :foo, batch: { id: :foo_id }`
      # - `attribute :foo, batch: { use: FooLoader, id: foo_id }`
      # - `attribute :foo, batch: { use: :foo_loader, id: foo_id }`
      #
      # In other cases we should never call tis method here.
      #
      def self.get(serializer_class, attribute_name, batch_opt)
        if batch_opt == true                        # ex: `batch: true`
          loader_name = attribute_name
          loader_id_method = :id
        elsif batch_opt.respond_to?(:call)          # ex: `batch: FooLoader`
          serializer_class.batch_loader(attribute_name, batch_opt)
          loader_name = attribute_name
          loader_id_method = :id
        else
          use = batch_opt[:use]
          loader_id_method = batch_opt[:id] || :id

          if use.respond_to?(:call)                 # ex: `batch: { use: FooLoader }`
            loader_name = attribute_name
            serializer_class.batch_loader(loader_name, use)
          else                                      # ex: `batch: { use: :foo }` || batch: { id: :some_id }
            loader_name = use || attribute_name
          end
        end

        AutoResolver.new(loader_name, loader_id_method)
      end
    end
  end
end
