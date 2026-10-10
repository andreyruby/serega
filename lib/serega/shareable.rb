# frozen_string_literal: true

class Serega
  #
  # Prepares serializers to be frozen and shared between Ractors
  #
  # @private
  class SeregaShareable
    # Freezes a class without the Serega.freeze override
    MODULE_FREEZE = Module.instance_method(:freeze)
    private_constant :MODULE_FREEZE

    class << self
      #
      # Makes the serializer and the serializers of its relations shareable
      # between Ractors, and freezes the serializers of its relations.
      # Serega.freeze freezes the serializer itself.
      #
      # @param serializer_class [Class<Serega>] Serializer
      #
      # @return [void]
      #
      def call(serializer_class)
        serializers = unfrozen_serializers(serializer_class)
        serializers.each { |serializer| prepare(serializer) }
        serializers.each { |serializer| share_definitions(serializer) }
        serializers.each { |serializer| MODULE_FREEZE.bind_call(serializer) unless serializer.equal?(serializer_class) }
      end

      private

      # The serializer and the unfrozen serializers its relations reach
      def unfrozen_serializers(serializer_class)
        found = {serializer_class => true}.compare_by_identity
        queue = [serializer_class]

        until queue.empty?
          queue.shift.attributes.each_value do |attribute|
            serializer = attribute.serializer
            next if !serializer || serializer.frozen? || found.key?(serializer)

            found[serializer] = true
            queue << serializer
          end
        end

        found.keys
      end

      def prepare(serializer)
        serializer.lock
        default_plan = serializer::SeregaPlan.new(nil, FROZEN_EMPTY_HASH)
        prepare_result_builders(default_plan)
        serializer.instance_variable_set(:@plan_cache, SeregaPlanCache::PerRactor.new(serializer, default_plan))
      end

      # Builds the result builders of the plan and its child plans in all
      # modes, except a mode that Ruby can not build (Data or Struct with
      # invalid member names)
      def prepare_result_builders(plan)
        %i[hash data struct].each do |mode|
          plan.result_builder(mode)
        rescue SeregaError
          nil
        end

        plan.relation_points.each { |point| prepare_result_builders(point.child_plan) }
      end

      def share_definitions(serializer)
        serializer.attributes.each_value do |attribute|
          share(attribute) do |error|
            "Attribute :#{attribute.name} of #{serializer} can not be shared between Ractors (#{attribute.location}): #{error.message}"
          end
        end

        serializer.batch_loaders.each_value do |loader|
          share(loader) { |error| "Batch loader :#{loader.name} of #{serializer} can not be shared between Ractors: #{error.message}" }
        end

        serializer.formatters.each do |name, formatter|
          share(formatter) { |error| "Formatter :#{name} of #{serializer} can not be shared between Ractors: #{error.message}" }
        end

        serializer.instance_variables.each do |name|
          share(serializer.instance_variable_get(name)) { |error| "#{serializer} can not be shared between Ractors: #{error.message}" }
        end

        share_constants(serializer::SeregaAttributeValues)
        share_instance_variables(serializer::SeregaResultBuilder)
      end

      def share_constants(values_class)
        values_class.constants(false).each { |name| Ractor.make_shareable(values_class.const_get(name, false)) }
      end

      def share_instance_variables(builder_class)
        builder_class.instance_variables.each { |name| Ractor.make_shareable(builder_class.instance_variable_get(name)) }
      end

      def share(value)
        Ractor.make_shareable(value)
      rescue Ractor::Error => error
        raise SeregaError, yield(error)
      end
    end
  end
end
