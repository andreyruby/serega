# frozen_string_literal: true

class Serega
  #
  # Serialization plans of one serializer, cached by modifiers.
  # Validates initiate options before building a plan.
  #
  # @private
  class SeregaPlanCache
    # Cached plan and whether its modifiers were validated
    CachedPlan = Struct.new(:plan, :validated)
    private_constant :CachedPlan

    #
    # SeregaPlanCache instance methods
    #
    # @private
    module InstanceMethods
      #
      # Initializes empty plans cache of the current serializer
      #
      def initialize
        @serializer_class = self.class.serializer_class
        @default_plan = nil
        @plans = {}
      end

      #
      # Returns serialization plan for provided modifiers.
      # The plan without modifiers is always cached; plans with modifiers are
      # cached when `max_cached_plans_per_serializer_count` is positive.
      # Modifiers are validated before building a plan.
      #
      # @param only [Hash, nil] The only attributes to serialize
      # @param with [Hash, nil] Attributes (usually marked `hide: true`) to serialize additionally
      # @param except [Hash, nil] Attributes to hide
      # @param check_initiate_params [Boolean] Validates modifiers
      #
      # @return [SeregaPlan] Serialization plan
      #
      def fetch(only, with, except, check_initiate_params: false)
        return default_plan if blank?(only) && blank?(with) && blank?(except)

        max_size = @serializer_class.config.max_cached_plans_per_serializer_count
        return build(only, with, except, check_initiate_params) if max_size.zero?

        cached_plan(only, with, except, max_size, check_initiate_params)
      end

      private

      def blank?(modifier)
        modifier.nil? || modifier.empty?
      end

      def default_plan
        @default_plan ||= @serializer_class::SeregaPlan.new(nil, FROZEN_EMPTY_HASH)
      end

      def cached_plan(only, with, except, max_size, check_initiate_params)
        key = [only || FROZEN_EMPTY_HASH, with || FROZEN_EMPTY_HASH, except || FROZEN_EMPTY_HASH]
        cached = @plans[key]
        return reuse(cached, only, with, except, check_initiate_params) if cached

        plan = build(only, with, except, check_initiate_params)
        @plans[frozen_copy(key)] = CachedPlan.new(plan, check_initiate_params)
        @plans.shift if @plans.length > max_size
        plan
      end

      def reuse(cached, only, with, except, check_initiate_params)
        if check_initiate_params && !cached.validated
          validate(only, with, except)
          cached.validated = true
        end

        cached.plan
      end

      def build(only, with, except, check_initiate_params)
        validate(only, with, except) if check_initiate_params
        @serializer_class::SeregaPlan.new(nil, {only: only, with: with, except: except})
      end

      def frozen_copy(key)
        SeregaUtils::EnumDeepFreeze.call(SeregaUtils::EnumDeepDup.call(key))
      end

      def validate(only, with, except)
        SeregaValidations::Initiate::CheckModifiers.new.call(@serializer_class, only, with, except)
      end
    end

    include InstanceMethods
    extend SeregaHelpers::SerializerClassHelper
  end
end
