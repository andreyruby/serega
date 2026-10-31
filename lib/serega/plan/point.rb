# frozen_string_literal: true

class Serega
  class SeregaPlan # :nodoc:
    #
    # One attribute in a plan, with the child plan of a relation
    #
    class Point # :nodoc:
      # Link to current plan this point belongs to
      attr_reader :plan

      # Shows current attribute
      attr_reader :attribute

      # Attribute `name`
      attr_reader :name

      # Preloads of the point, given by the selection
      attr_reader :preloads

      # Shows child plan if exists
      attr_reader :child_plan

      # Whether the relation values of a class are collections, for a point
      # with a child plan
      attr_reader :collection_classes

      # Initializes plan point. A point with a child selection gets a child
      # plan of it.
      def initialize(plan, attribute, preloads, child_selection)
        @plan = plan
        @attribute = attribute
        @name = attribute.name
        @preloads = preloads
        @child_plan = child_selection ? SeregaPlan.new(child_selection, self) : nil
        @collection_classes = @child_plan ? {}.compare_by_identity : nil
      end

      # Attribute names from the root plan down to this point
      def path
        names = [name]
        point = self
        names.unshift(point.name) while (point = point.plan.parent_plan_point)
        names
      end

      # Attribute `many` option
      def many
        attribute.many
      end

      # Attribute `batch_loaders`
      def batch_loaders
        attribute.batch_loaders
      end

      # Attribute `conditional?`
      def conditional?
        attribute.conditional?
      end
    end
  end
end
