# frozen_string_literal: true

class Serega
  module SeregaValidations
    module Attribute
      #
      # Attribute `:batch` option validator
      #
      class CheckOptBatch
        class << self
          #
          # Checks attribute :batch option
          #
          # @param opts [Hash] Attribute options
          #
          # @raise [SeregaError] Attribute validation error
          #
          # @return [void]
          #
          def call(serializer_class, opts, block)
            return unless opts.key?(:batch)

            check_opt_batch(opts, serializer_class)
            check_usage_with_other_params(opts, block)
          end

          private

          def check_opt_batch(opts, serializer_class)
            batch_opts = opts[:batch]
            return if batch_opts == true
            return if batch_opts.respond_to?(:call)

            if batch_opts.is_a?(Symbol) || batch_opts.is_a?(String)
              check_loader_exists?(serializer_class, batch_opts)
            else
              Utils::CheckOptIsHash.call(opts, :batch)
              check_opt_batch_use(serializer_class, batch_opts)
              check_opt_batch_id(batch_opts)
              check_opt_batch_extra_opts(batch_opts)
            end
          end

          def check_opt_batch_use(serializer_class, batch_opts)
            return unless batch_opts.key?(:use)

            batch_loader_name = batch_opts[:use]
            return if batch_loader_name.respond_to?(:call)

            check_loader_exists?(serializer_class, batch_loader_name)
          end

          def check_opt_batch_id(batch_opts)
            return unless batch_opts.key?(:id)

            id_method_name = batch_opts[:id]
            return if id_method_name.is_a?(Symbol) || id_method_name.is_a?(String)

            raise SeregaError, "Invalid batch option `:id` value, it can be a Symbol or a String"
          end

          def check_loader_exists?(serializer_class, value)
            values = Array(value)
            values.each do |batch_loader_name|
              next if serializer_class.batch_loaders.key?(batch_loader_name.to_sym)

              raise SeregaError, "Batch loader with name `#{batch_loader_name.inspect}` is not defined"
            end
          end

          def check_opt_batch_extra_opts(batch_opts)
            Utils::CheckAllowedKeys.call(batch_opts, %i[use id], :batch)
          end

          def check_usage_with_other_params(opts, block)
            batch = opts[:batch]
            use_id = batch.is_a?(Hash) && batch.key?(:id)
            use_multiple = batch.is_a?(Hash) && (Array(batch[:use]).size > 1)
            value_added = opts.key?(:value) || block

            if use_multiple && use_id
              raise SeregaError, "Option `batch.id` should not be used with multiple loaders provided in `batch.use`"
            end

            if use_multiple && !value_added
              raise SeregaError, "Attribute :value option or block should be provided when selecting multiple batch loaders"
            end

            if use_id && value_added
              raise SeregaError, "Option `batch.id` should not be used when :value or block provided directly"
            end

            raise SeregaError, "Option :batch can not be used together with option :method" if opts.key?(:method)
            raise SeregaError, "Option :batch can not be used together with option :const" if opts.key?(:const)
            raise SeregaError, "Option :batch can not be used together with option :delegate" if opts.key?(:delegate)
          end
        end
      end
    end
  end
end
