# frozen_string_literal: true

class Serega
  #
  # Builds Data objects from serialized hashes.
  # Used by `#to_data` / `.to_data`.
  #
  class SeregaDataBuilder
    # SeregaDataBuilder class methods
    module SeregaDataBuilderClassMethods
      #
      # Converts serialized Hash/Array result into a tree of Ruby Data objects
      # following the serializer's plan structure.
      #
      # @param serializer [Serega] Serializer instance carrying the plan
      # @param serialized [Hash, Array, nil] Serialized output from `#to_h`
      #
      # @return [Data, Array<Data>, nil] Serialization result as Data object(s)
      #
      def call(serializer, serialized)
        build(serialized, serializer.plan)
      end

      private

      def build(serialized, plan)
        case serialized
        when Array then serialized.map { |item| hash_to_data(item, plan) }
        when Hash then hash_to_data(serialized, plan)
        else serialized
        end
      end

      def hash_to_data(hash, plan)
        hash_data = hash.to_h do |key, value|
          child_plan = plan.points_hash.fetch(key).child_plan
          value = build(value, child_plan) if child_plan
          [key, value]
        end

        build_data_object(plan, hash_data)
      end

      def build_data_object(plan, hash_data)
        plan.data_class.new(**hash_data)
      end
    end

    extend SeregaHelpers::SerializerClassHelper
    extend SeregaDataBuilderClassMethods
  end
end
