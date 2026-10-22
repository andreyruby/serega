# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Attribute # :nodoc:
      #
      # Attribute `:batch` option validator
      #
      class CheckOptBatch # :nodoc:
        class << self
          # Checks attribute :batch option
          def call(serializer_class, name, opts)
            return unless opts.key?(:batch)

            check_type(opts)
            batch = AttributeNormalizers::Batch.new(opts[:batch], name)
            check_loaders_exist(serializer_class, batch)
            check_usage_with_other_params(opts, batch)
          end

          private

          # `true`, a loader name, a callable or a Hash with :use and :id
          def check_type(opts)
            batch = opts[:batch]
            return if batch == true || batch.is_a?(Symbol) || batch.is_a?(String) || batch.respond_to?(:call)

            Utils::CheckOptIsHash.call(opts, :batch)
            Utils::CheckAllowedKeys.call(batch, %i[use id], :batch)
            check_id(batch)
          end

          def check_id(batch)
            return unless batch.key?(:id)

            id_method_name = batch[:id]
            return if id_method_name.is_a?(Symbol) || id_method_name.is_a?(String)

            raise SeregaError, "Invalid batch option `:id` value, it can be a Symbol or a String"
          end

          # Checks the names as given, thus the error shows a String name as a String
          def check_loaders_exist(serializer_class, batch)
            return if batch.inline?

            Array(batch.use).each do |batch_loader_name|
              next if serializer_class.batch_loaders.key?(batch_loader_name.to_sym)

              raise SeregaError, "Batch loader with name `#{batch_loader_name.inspect}` is not defined"
            end
          end

          def check_usage_with_other_params(opts, batch)
            use_id = !batch.id.nil?
            use_multiple = Array(batch.use).size > 1
            value_added = opts.key?(:value)

            if use_multiple && use_id
              raise SeregaError, "Option `batch.id` should not be used with multiple loaders provided in `batch.use`"
            end

            if use_multiple && !value_added
              raise SeregaError, "Attribute :value option should be provided when selecting multiple batch loaders"
            end

            if use_id && value_added
              raise SeregaError, "Option `batch.id` should not be used when :value option provided directly"
            end
          end
        end
      end
    end
  end
end
