# frozen_string_literal: true

class Serega
  class SeregaPlan # :nodoc:
    #
    # Shareable plans cache of a shareable serializer, keeps the plans of each
    # Ractor apart
    #
    class PerRactorCache # :nodoc:
      # Keeps the plans of the serializer with the planner in a Cache per
      # Ractor, under a key of the serializer and the planner
      def initialize(serializer_class, planner)
        @serializer_class = serializer_class
        @planner = planner
        @key = SeregaUtils::RactorLocal.key(serializer_class, "plan_cache_#{planner.object_id}")
        freeze
      end

      # Returns serialization plan from the plans cache of the current Ractor.
      # Takes the parameters one by one like Cache#fetch: a splat allocates
      # an Array on every `Serega.new`.
      def fetch(param1 = nil, param2 = nil, param3 = nil, check_initiate_params: nil)
        plan_cache = SeregaUtils::RactorLocal.fetch(@key) { SeregaPlan::Cache.new(@serializer_class, @planner) }
        plan_cache.fetch(param1, param2, param3, check_initiate_params: check_initiate_params)
      end
    end
  end
end
