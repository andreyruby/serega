# frozen_string_literal: true

class Serega
  class SeregaPlan # :nodoc:
    #
    # Depth limit of plans: the levels of child plans that `config.depth_limit`
    # of the root serializer allows below a plan.
    #
    module DepthLimit # :nodoc:
      class << self
        # Depth left below a plan: the depth limit of the serializer for a
        # root plan, one level less than the parent plan's for a child plan,
        # `nil` without a limit. Raises DepthLimitError when the parent plan
        # has no level left.
        def depth_left(serializer_class, parent_plan_point)
          return serializer_class.config.depth_limit unless parent_plan_point

          parent_depth_left = parent_plan_point.plan.depth_left
          return unless parent_depth_left
          return parent_depth_left - 1 if parent_depth_left > 1

          raise_depth_limit_error(parent_plan_point)
        end

        private

        def raise_depth_limit_error(parent_plan_point)
          root_serializer = parent_plan_point.plan.root_plan.serializer_class
          limit = root_serializer.config.depth_limit
          path = parent_plan_point.path.join(" -> ")
          raise DepthLimitError.new("Depth limit was exceeded", "#{root_serializer} (depth limit: #{limit}) -> #{path}\n(hint: if the nesting is not a cycle, increase config.depth_limit of #{root_serializer})")
        end
      end
    end
  end
end
