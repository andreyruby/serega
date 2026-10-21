# frozen_string_literal: true

class Serega
  #
  # Combines attribute and nested attributes
  #
  class SeregaPlanPoint # :nodoc:
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

    # Initializes plan point
    def initialize(plan, attribute, modifiers = nil)
      @plan = plan
      @attribute = attribute
      @name = attribute.name
      @child_plan = serializer ? SeregaPlan.new(serializer, self, modifiers || FROZEN_EMPTY_HASH) : nil
      @collection_classes = @child_plan ? {}.compare_by_identity : nil
    end

    # Attribute `many` option
    def many
      attribute.many
    end

    # Attribute `serializer` option
    def serializer
      attribute.serializer
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
