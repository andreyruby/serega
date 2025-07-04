# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module Batch
      #
      # SeregaAttributeNormalizer additional/patched instance methods
      #
      # @see SeregaAttributeNormalizer::AttributeInstanceMethods
      #
      module AttributeNormalizerInstanceMethods
        #
        # Returns normalized attribute :batch option with prepared :key and
        # :default options. Option :loader will be prepared at serialization
        # time as loaders are usually defined after attributes.
        #
        # @return [Hash] attribute :batch normalized options
        #
        def batch
          return @batch if instance_variable_defined?(:@batch)

          @batch = prepare_batch
        end

        private

        #
        # Patch for original `prepare_hide` method
        #
        # Marks attribute hidden if auto_hide option was set and attribute has batch loader
        #
        def prepare_hide
          res = super
          return res unless res.nil?

          self.class.serializer_class.config.batch.auto_hide || nil if batch
        end

        # Do not add any preloads automatically when batch option provided
        def prepare_preloads
          return if init_opts.key?(:batch) && !init_opts.key?(:preload)

          super
        end

        def prepare_batch
          batch = init_opts[:batch]
          return unless batch

          loader = prepare_batch_loader(batch[:loader])

          id_method = batch[:id_method] || self.class.serializer_class.config.batch.id_method
          id_method = prepare_batch_id_method(id_method)

          {loader: loader, id_method: id_method, default: default}
        end

        def prepare_batch_id_method(id_method)
          return proc { |object| object.public_send(id_method) } if id_method.is_a?(Symbol)

          signature = SeregaUtils::MethodSignature.call(id_method, pos_limit: 2, keyword_args: [])
          case signature
          when "0" then proc { id_method.call }
          when "1" then proc { |object| id_method.call(object) }
          else id_method
          end
        end

        def prepare_batch_loader(loader)
          loader = self.class.serializer_class.config.batch.loaders.fetch(loader) if loader.is_a?(Symbol)

          signature = SeregaUtils::MethodSignature.call(loader, pos_limit: 3, keyword_args: [])
          case signature
          when "0" then proc { loader.call }
          when "1" then proc { |object| loader.call(object) }
          when "2" then proc { |object, context| loader.call(object, context) }
          else loader
          end
        end
      end
    end
  end
end
