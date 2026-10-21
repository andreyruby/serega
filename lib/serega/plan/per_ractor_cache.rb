# frozen_string_literal: true

class Serega
  class SeregaPlan # :nodoc:
    #
    # Shareable plans cache of a shareable serializer, keeps the plans of each
    # Ractor apart
    #
    class PerRactorCache # :nodoc:
      def initialize(serializer_class)
        @serializer_class = serializer_class
        @key = SeregaUtils::RactorLocal.key(serializer_class, :plan_cache)
        freeze
      end

      # Returns serialization plan from the plans cache of the current Ractor
      def fetch(only, with, except, check_initiate_params: false)
        plan_cache = SeregaUtils::RactorLocal.fetch(@key) { SeregaPlan::Cache.new(@serializer_class) }
        plan_cache.fetch(only, with, except, check_initiate_params: check_initiate_params)
      end
    end
  end
end
