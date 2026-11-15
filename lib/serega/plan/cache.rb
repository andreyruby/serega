# frozen_string_literal: true

class Serega
  class SeregaPlan # :nodoc:
    #
    # Serialization plans of one serializer, cached by up to four
    # parameters, such as the `only`, `with` and `except` field selection
    # options and the `preset`. The planner parses and validates the parameters and builds
    # the plans.
    #
    class Cache # :nodoc:
      # Cached plan, whether its parameters were validated, and the
      # parameters as provided
      CACHED_PLAN = Struct.new(:plan, :validated, :param1, :param2, :param3, :param4) do
        # Whether the given parameters equal the cached ones
        def same_params?(param1, param2, param3, param4)
          param1.eql?(self.param1) && param2.eql?(self.param2) && param3.eql?(self.param3) && param4.eql?(self.param4)
        end

        # Validates the cached parameters with the planner, once
        def validate(planner, serializer_class)
          return if validated

          planner.validate(serializer_class, planner.parse(serializer_class, param1, param2, param3, param4))
          self.validated = true
        end
      end
      private_constant :CACHED_PLAN

      # Initializes empty plans cache of the serializer with the planner of
      # its parameters
      def initialize(serializer_class, planner)
        @serializer_class = serializer_class
        @planner = planner
        @default_plan = nil
        @plans = {}
      end

      # Returns serialization plan for provided parameters. The planner gives
      # them their meaning, for example `only`, `with`, `except` and `preset`; a planner
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
      def fetch(param1 = nil, param2 = nil, param3 = nil, param4 = nil, check_initiate_params: nil)
        return default_plan if param1.nil? && param2.nil? && param3.nil? && param4.nil?

        config = @serializer_class.config
        check_initiate_params = config.check_initiate_params if check_initiate_params.nil?
        max_size = config.max_cached_plans_per_serializer_count
        return build(param1, param2, param3, param4, check_initiate_params) if max_size.zero?

        cached_plan(param1, param2, param3, param4, max_size, check_initiate_params)
      end

      private

      # The plan without parameters, built by the planner from no parameters
      def default_plan
        @default_plan ||= @planner.plan(@serializer_class, @planner.parse(@serializer_class))
      end

      # Keeps plans by the key of the parameters, and compares each
      # parameter with the cached one. Parameters with the key of other
      # cached parameters replace them.
      def cached_plan(param1, param2, param3, param4, max_size, check_initiate_params)
        key = cache_key(param1, param2, param3, param4)
        cached = @plans[key]
        if cached&.same_params?(param1, param2, param3, param4)
          cached.validate(@planner, @serializer_class) if check_initiate_params
          return cached.plan
        end

        plan = build(param1, param2, param3, param4, check_initiate_params)
        @plans[key] = CACHED_PLAN.new(plan, check_initiate_params, *frozen_copy([param1, param2, param3, param4]))
        @plans.shift if @plans.length > max_size
        plan
      end

      # The hash of the hash values of the parameters: an Array of the
      # parameters as the key hashes and compares nested arrays inside a
      # recursion guard. A lone parameter is keyed by its own hash, salted by
      # its position, so `only: x`, `with: x`, `except: x` and `preset: x`
      # have different keys. It skips the Array and takes 11% off a cached
      # `Serega.new` with one option or preset. A missing fourth parameter
      # stays out of the Array: the longer Array adds about 4 ns.
      def cache_key(param1, param2, param3, param4)
        # rubocop:disable Security/CompoundHash -- `[param1, param2, param3].hash` hashes nested arrays inside a recursion guard
        if param2.nil? && param3.nil? && param4.nil? then param1.hash ^ 0 # salt 0
        elsif param1.nil? && param3.nil? && param4.nil? then param2.hash ^ 1 # salt 1
        elsif param1.nil? && param2.nil? && param4.nil? then param3.hash ^ 2 # salt 2
        elsif param1.nil? && param2.nil? && param3.nil? then param4.hash ^ 3 # salt 3
        elsif param4.nil? then [param1.hash, param2.hash, param3.hash].hash
        else [param1.hash, param2.hash, param3.hash, param4.hash].hash
        end
        # rubocop:enable Security/CompoundHash
      end

      def build(param1, param2, param3, param4, check_initiate_params)
        params = @planner.parse(@serializer_class, param1, param2, param3, param4)
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
