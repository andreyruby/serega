# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  module AttributeValueResolvers # :nodoc:
    #
    # Value resolver of attributes with the :batch option and without the
    # :value option. Reads the value of the object from the loaded batch.
    #
    class Batch < Base # :nodoc:
      def initialize(loader_name, id_method)
        @loader_name = loader_name
        @id_method = id_method
      end

      # Finds the object attribute value in the loaded batches
      def call(obj, batches:)
        batches.fetch(@loader_name)[obj.public_send(@id_method)]
      end

      # Ruby code that reads the value of the source from the loaded batch
      # of the loader, which `batch_variable` holds
      def batch_code(source_variable, batch_variable)
        id_method = @id_method
        id_code =
          if SeregaResultCode::PLAIN_METHOD_NAME.match?(id_method)
            "#{source_variable}.#{id_method}"
          else
            "#{source_variable}.public_send(#{id_method.inspect})"
          end
        "#{batch_variable}[#{id_code}]"
      end
    end
  end
end
