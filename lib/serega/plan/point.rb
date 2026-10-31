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

      # Shows child plan if exists
      attr_reader :child_plan

      # Whether the relation values of a class are collections, for a point
      # with a child plan
      attr_reader :collection_classes

      # Initializes plan point. A point with a child selection gets a child
      # plan of the relation serializer.
      def initialize(plan, attribute, child_selection = nil)
        @plan = plan
        @attribute = attribute
        @name = attribute.name
        @child_plan = child_selection ? SeregaPlan.new(child_selection, self) : nil
        @collection_classes = @child_plan ? {}.compare_by_identity : nil
      end

      # Attribute `many` option
      def many
        attribute.many
      end

      # Attribute `batch_loaders`
      def batch_loaders
        attribute.batch_loaders
      end

      # Attribute `preloads`
      def preloads
        attribute.preloads
      end

      # Attribute `conditional?`
      def conditional?
        attribute.conditional?
      end
    end
  end
end
