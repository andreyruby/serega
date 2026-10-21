# frozen_string_literal: true

class Serega
  #
  # Makes a serializer shareable between Ractors
  #
  # @private
  class SeregaShareable
    class << self
      #
      # Makes the serializer definitions shareable between Ractors, except the
      # plans cache. A definition that can not be shared stays as it is.
      #
      # @param serializer_class [Class<Serega>] Serializer
      #
      # @return [String, nil] First reason a definition can not be shared
      #
      def call(serializer_class)
        reasons = []

        serializer_class.attributes.each_value do |attribute|
          share(attribute, reasons) do |message|
            "Attribute :#{attribute.name} of #{serializer_class} can not be shared between Ractors (#{attribute.location}): #{message}"
          end
        end

        serializer_class.batch_loaders.each_value do |loader|
          share(loader, reasons) { |message| "Batch loader :#{loader.name} of #{serializer_class} can not be shared between Ractors: #{message}" }
        end

        serializer_class.formatters.each do |name, formatter|
          share(formatter, reasons) { |message| "Formatter :#{name} of #{serializer_class} can not be shared between Ractors: #{message}" }
        end

        (serializer_class.instance_variables - [:@plan_cache]).each do |name|
          value = serializer_class.instance_variable_get(name)
          share(value, reasons) { |message| "#{serializer_class} can not be shared between Ractors: #{message}" }
        end

        share_constants(serializer_class::SeregaAttributeValues, reasons)
        reasons.first
      end

      private

      def share_constants(values_class, reasons)
        values_class.constants(false).each do |name|
          share(values_class.const_get(name, false), reasons) { |message| "#{values_class} can not be shared between Ractors: #{message}" }
        end
      end

      def share(value, reasons)
        Ractor.make_shareable(value)
      rescue Ractor::Error, ArgumentError => error
        reasons << -yield(error.message)
      end
    end
  end
end
