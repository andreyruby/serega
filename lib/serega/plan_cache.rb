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
      # cached by modifiers as provided when `max_cached_plans_per_serializer_count`
      # is positive. Modifiers are parsed and validated when a plan is built.
      #
      # @param only [Hash, Array, String, Symbol, nil] The only attributes to serialize
      # @param with [Hash, Array, String, Symbol, nil] Attributes (usually marked `hide: true`) to serialize additionally
      # @param except [Hash, Array, String, Symbol, nil] Attributes to hide
      # @param check_initiate_params [Boolean] Validates modifiers
      #
      # @return [SeregaPlan] Serialization plan
      #
      def fetch(only, with, except, check_initiate_params: false)
        return default_plan if only.nil? && with.nil? && except.nil?

        max_size = @serializer_class.config.max_cached_plans_per_serializer_count
        return build(only, with, except, check_initiate_params) if max_size.zero?

        cached_plan(only, with, except, max_size, check_initiate_params)
      end

      private

      def default_plan
        @default_plan ||= @serializer_class::SeregaPlan.new(nil, FROZEN_EMPTY_HASH)
      end

      def cached_plan(only, with, except, max_size, check_initiate_params)
        key = [only, with, except]
        cached = @plans[key]
        return reuse(cached, only, with, except, check_initiate_params) if cached

        plan = build(only, with, except, check_initiate_params)
        @plans[frozen_copy(key)] = CachedPlan.new(plan, check_initiate_params)
        @plans.shift if @plans.length > max_size
        plan
      end

      def reuse(cached, only, with, except, check_initiate_params)
        if check_initiate_params && !cached.validated
          validate(parse_modifiers(only, with, except))
          cached.validated = true
        end

        cached.plan
      end

      def build(only, with, except, check_initiate_params)
        modifiers = parse_modifiers(only, with, except)
        return default_plan if modifiers[:only].empty? && modifiers[:with].empty? && modifiers[:except].empty?

        validate(modifiers) if check_initiate_params
        @serializer_class::SeregaPlan.new(nil, modifiers)
      end

      def parse_modifiers(only, with, except)
        {only: parse_modifier(only), with: parse_modifier(with), except: parse_modifier(except)}
      end

      # Patched in:
      # - plugin :string_modifiers (parses string modifiers differently)
      def parse_modifier(value)
        SeregaUtils::ToHash.call(value)
      end

      def frozen_copy(key)
        SeregaUtils::EnumDeepFreeze.call(SeregaUtils::EnumDeepDup.call(key))
      end

      def validate(modifiers)
        SeregaValidations::Initiate::CheckModifiers.new.call(@serializer_class, modifiers[:only], modifiers[:with], modifiers[:except])
      end
    end

    include InstanceMethods
    extend SeregaHelpers::SerializerClassHelper

    #
    # Shareable plans cache of a frozen serializer, keeps the plans of each
    # Ractor apart
    #
    # @private
    class PerRactor
      #
      # @param serializer_class [Class<Serega>] Serializer of the plans
      # @param error [String, nil] Why the serializer can not serialize in
      #   other Ractors
      #
      def initialize(serializer_class, error)
        @serializer_class = serializer_class
        @error = error
        @key = SeregaUtils::RactorLocal.key(serializer_class, :plan_cache)
        freeze
      end

      #
      # Returns serialization plan from the plans cache of the current Ractor
      #
      # @raise [SeregaError] when the serializer can not serialize in the
      #   current Ractor
      #
      # @see SeregaPlanCache::InstanceMethods#fetch
      #
      def fetch(only, with, except, check_initiate_params: false)
        error = @error
        # :nocov:
        raise SeregaError, error if error && !Ractor.current.equal?(Ractor.main)
        # :nocov:

        plan_cache = SeregaUtils::RactorLocal.fetch(@key) { @serializer_class::SeregaPlanCache.new }
        plan_cache.fetch(only, with, except, check_initiate_params: check_initiate_params)
      end
    end
  end
end
