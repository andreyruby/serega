# frozen_string_literal: true

class Serega
  class SeregaPlan # :nodoc:
    #
    # Serialization plans of one serializer, cached by modifiers.
    # Validates initiate options before building a plan.
    #
    class Cache # :nodoc:
      # Cached plan, whether its modifiers were validated, and the modifiers
      # as provided
      CachedPlan = Struct.new(:plan, :validated, :only, :with, :except)
      private_constant :CachedPlan

      # Initializes empty plans cache of the serializer
      def initialize(serializer_class)
        @serializer_class = serializer_class
        @default_plan = nil
        @plans = {}
      end

      # Returns serialization plan for provided modifiers.
      # The plan without modifiers is always cached; plans with modifiers are
      # cached by modifiers as provided when `max_cached_plans_per_serializer_count`
      # is positive. Modifiers are parsed and validated when a plan is built.
      def fetch(only, with, except, check_initiate_params: false)
        return default_plan if only.nil? && with.nil? && except.nil?

        max_size = @serializer_class.config.max_cached_plans_per_serializer_count
        return build(only, with, except, check_initiate_params) if max_size.zero?

        cached_plan(only, with, except, max_size, check_initiate_params)
      end

      private

      def default_plan
        @default_plan ||= SeregaPlan.new(Selection.new(@serializer_class, FROZEN_EMPTY_HASH))
      end

      # Keeps plans by the hash of the hash values of the modifiers, and
      # compares each modifier with the cached one: an Array of the modifiers
      # as the key hashes and compares nested arrays inside a recursion guard.
      # Modifiers with the hash of other cached modifiers replace them.
      def cached_plan(only, with, except, max_size, check_initiate_params)
        key = [only.hash, with.hash, except.hash].hash # rubocop:disable Security/CompoundHash -- `[only, with, except].hash` hashes nested arrays inside a recursion guard
        cached = @plans[key]
        return reuse(cached, only, with, except, check_initiate_params) if cached && same_modifiers?(cached, only, with, except)

        plan = build(only, with, except, check_initiate_params)
        @plans[key] = CachedPlan.new(plan, check_initiate_params, *frozen_copy([only, with, except]))
        @plans.shift if @plans.length > max_size
        plan
      end

      def same_modifiers?(cached, only, with, except)
        only.eql?(cached.only) && with.eql?(cached.with) && except.eql?(cached.except)
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
        SeregaPlan.new(Selection.new(@serializer_class, modifiers))
      end

      def parse_modifiers(only, with, except)
        {only: parse_modifier(only), with: parse_modifier(with), except: parse_modifier(except)}
      end

      def parse_modifier(value)
        return SeregaUtils::ParseStringModifiers.parse(value) if value.is_a?(String)

        SeregaUtils::ToHash.call(value)
      end

      def frozen_copy(modifiers)
        SeregaUtils::EnumDeepFreeze.call(SeregaUtils::EnumDeepDup.call(modifiers))
      end

      def validate(modifiers)
        SeregaValidations::Initiate::CheckModifiers.new.call(@serializer_class, modifiers[:only], modifiers[:with], modifiers[:except])
      end
    end
  end
end
