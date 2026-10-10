# frozen_string_literal: true

class Serega
  #
  # Makes a frozen serializer shareable between Ractors
  #
  # @private
  class SeregaShareable
    class << self
      #
      # Makes the serializer definitions shareable between Ractors, and gives
      # the serializer a plans cache per Ractor. A definition that can not be
      # shared stays as it is, and the plans cache keeps the first reason.
      #
      # @param serializer_class [Class<Serega>] Serializer
      #
      # @return [void]
      #
      def call(serializer_class)
        errors = []

        serializer_class.attributes.each_value do |attribute|
          share(attribute, errors) do |error|
            "Attribute :#{attribute.name} of #{serializer_class} can not be shared between Ractors (#{attribute.location}): #{error.message}"
          end
        end

        serializer_class.batch_loaders.each_value do |loader|
          share(loader, errors) { |error| "Batch loader :#{loader.name} of #{serializer_class} can not be shared between Ractors: #{error.message}" }
        end

        serializer_class.formatters.each do |name, formatter|
          share(formatter, errors) { |error| "Formatter :#{name} of #{serializer_class} can not be shared between Ractors: #{error.message}" }
        end

        serializer_class.instance_variables.each do |name|
          value = serializer_class.instance_variable_get(name)
          share(value, errors) { |error| "#{serializer_class} can not be shared between Ractors: #{error.message}" }
        end

        share_constants(serializer_class::SeregaAttributeValues, errors)
        share_instance_variables(serializer_class::SeregaResultBuilder)

        plan_cache = SeregaPlanCache::PerRactor.new(serializer_class, errors.first)
        serializer_class.instance_variable_set(:@plan_cache, plan_cache)
      end

      private

      def share_constants(values_class, errors)
        values_class.constants(false).each do |name|
          share(values_class.const_get(name, false), errors) { |error| "#{values_class} can not be shared between Ractors: #{error.message}" }
        end
      end

      def share_instance_variables(builder_class)
        builder_class.instance_variables.each { |name| Ractor.make_shareable(builder_class.instance_variable_get(name)) }
      end

      def share(value, errors)
        Ractor.make_shareable(value)
      rescue Ractor::Error, ArgumentError => error
        errors << -yield(error)
      end
    end
  end
end
