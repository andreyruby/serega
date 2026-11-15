# frozen_string_literal: true

class Serega
  class SeregaPlan # :nodoc:
    #
    # Depth limit of plans: the levels of child plans that `config.depth_limit`
    # of the root serializer allows below a plan. Without a limit, it stops a
    # cycle of relations.
    #
    module DepthLimit # :nodoc:
      class << self
        # Depth left below the plan of a selection: the depth limit of the
        # serializer for a root plan, one level less than the parent plan's
        # for a child plan, `nil` without a limit. Raises DepthLimitError when
        # the parent plan has no level left, or, without a limit, when a
        # parent plan has the same selection and would repeat without end.
        def depth_left(selection, parent_plan_point)
          return selection.serializer_class.config.depth_limit unless parent_plan_point

          parent_depth_left = parent_plan_point.plan.depth_left
          return check_cycle(selection, parent_plan_point) unless parent_depth_left
          return parent_depth_left - 1 if parent_depth_left > 1

          raise_depth_limit_error(parent_plan_point)
        end

        private

        def check_cycle(selection, parent_plan_point)
          point = parent_plan_point

          while point
            plan = point.plan
            raise_cycle_error(parent_plan_point) if plan.selection == selection

            point = plan.parent_plan_point
          end
        end

        def raise_depth_limit_error(parent_plan_point)
          root_serializer = parent_plan_point.plan.root_plan.serializer_class
          limit = root_serializer.config.depth_limit
          path = parent_plan_point.path.join(" -> ")
          raise DepthLimitError.new("Depth limit was exceeded", "#{root_serializer} (depth limit: #{limit}) -> #{path}\n(hint: if the nesting is not a cycle, increase config.depth_limit of #{root_serializer})")
        end

        def raise_cycle_error(parent_plan_point)
          root_serializer = parent_plan_point.plan.root_plan.serializer_class
          path = parent_plan_point.path.join(" -> ")
          raise DepthLimitError.new("Relations nest in a cycle", "#{root_serializer} -> #{path}\n(hint: hide a relation of the cycle or set config.depth_limit)")
        end
      end
    end
  end
end
