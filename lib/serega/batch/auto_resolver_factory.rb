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

        AutoResolver.new(batch_name, batch_id_method)
      end
    end
  end
end
