# frozen_string_literal: true

class Serega
  class SeregaPlan # :nodoc:
    #
    # Serialization plans of one serializer, cached by up to three
    # parameters, such as the `only`, `with` and `except` modifiers. The
    # planner parses and validates the parameters and builds the plans.
    #
    class Cache # :nodoc:
      # Cached plan, whether its parameters were validated, and the
      # parameters as provided
      CachedPlan = Struct.new(:plan, :validated, :param1, :param2, :param3) do
        # Whether the given parameters equal the cached ones
        def same_params?(param1, param2, param3)
          param1.eql?(self.param1) && param2.eql?(self.param2) && param3.eql?(self.param3)
        end

        # Validates the cached parameters with the planner, once
        def validate(planner, serializer_class)
          return if validated

          planner.validate(serializer_class, planner.parse(param1, param2, param3))
          self.validated = true
        end
      end
      private_constant :CachedPlan

      # Initializes empty plans cache of the serializer with the planner of
      # its parameters
      def initialize(serializer_class, planner)
        @serializer_class = serializer_class
        @planner = planner
        @default_plan = nil
        @plans = {}
      end

      # Returns serialization plan for provided parameters. The planner gives
      # them their meaning, for example `only`, `with` and `except`; a planner
      # with fewer parameters leaves the last ones out. They are separate
      # arguments, not an Array: an Array, a splat or a Struct allocates on
      # every `Serega.new`, which adds 13 to 36 ns to a cached `Serega.new`
      # of about 114 ns.
      #
      # The plan without parameters is always cached; plans with parameters
      # are cached by parameters as provided when
      # `max_cached_plans_per_serializer_count` is positive. Parameters are
      # parsed when a plan is built, and validated when
      # `check_initiate_params` is true, or nil with
      # `config.check_initiate_params` on.
      def fetch(param1 = nil, param2 = nil, param3 = nil, check_initiate_params: nil)
        return default_plan if param1.nil? && param2.nil? && param3.nil?

        config = @serializer_class.config
        check_initiate_params = config.check_initiate_params if check_initiate_params.nil?
        max_size = config.max_cached_plans_per_serializer_count
        return build(param1, param2, param3, check_initiate_params) if max_size.zero?

        cached_plan(param1, param2, param3, max_size, check_initiate_params)
      end

      private

      # The plan without parameters, built by the planner from no parameters
      def default_plan
        @default_plan ||= @planner.plan(@serializer_class, @planner.parse)
      end

      # Keeps plans by the hash of the hash values of the parameters, and
      # compares each parameter with the cached one: an Array of the
      # parameters as the key hashes and compares nested arrays inside a
      # recursion guard. Parameters with the hash of other cached parameters
      # replace them.
      def cached_plan(param1, param2, param3, max_size, check_initiate_params)
        key = [param1.hash, param2.hash, param3.hash].hash # rubocop:disable Security/CompoundHash -- `[param1, param2, param3].hash` hashes nested arrays inside a recursion guard
        cached = @plans[key]
        if cached&.same_params?(param1, param2, param3)
          cached.validate(@planner, @serializer_class) if check_initiate_params
          return cached.plan
        end

        plan = build(param1, param2, param3, check_initiate_params)
        @plans[key] = CachedPlan.new(plan, check_initiate_params, *frozen_copy([param1, param2, param3]))
        @plans.shift if @plans.length > max_size
        plan
      end

      def build(param1, param2, param3, check_initiate_params)
        params = @planner.parse(param1, param2, param3)
        return default_plan if @planner.empty?(params)

        @planner.validate(@serializer_class, params) if check_initiate_params
        @planner.plan(@serializer_class, params)
      end

      def frozen_copy(params)
        SeregaUtils::EnumDeepFreeze.call(SeregaUtils::EnumDeepDup.call(params))
      end
    end
  end
end
