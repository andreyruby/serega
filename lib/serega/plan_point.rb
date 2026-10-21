# frozen_string_literal: true

class Serega
  #
  # Combines attribute and nested attributes
  #
  class SeregaPlanPoint # :nodoc:
    # Link to current plan this point belongs to
    # @return [SeregaAttribute] Current plan
    attr_reader :plan

    # Shows current attribute
    # @return [SeregaAttribute] Current attribute
    attr_reader :attribute

    # Attribute `name`
    # @return [Symbol] Attribute name
    attr_reader :name

    # Shows child plan if exists
    # @return [SeregaPlan, nil] Attribute serialization plan
    attr_reader :child_plan

    # Whether the relation values of a class are collections, for a point
    # with a child plan
    # @return [Hash{Class => Boolean}, nil] Answers by class, see SeregaUtils::CollectionDetector
    attr_reader :collection_classes

    #
    # Initializes plan point
    #
    # @param plan [SeregaPlan] Current plan this point belongs to
    # @param attribute [SeregaAttribute] Attribute to construct plan point
    # @param modifiers Serialization parameters
    # @option modifiers [Hash] :only The only attributes to serialize
    # @option modifiers [Hash] :except Attributes to hide
    # @option modifiers [Hash] :with Hidden attributes to serialize additionally
    #
    # @return [SeregaPlanPoint] New plan point
    #
    def initialize(plan, attribute, modifiers = nil)
      @plan = plan
      @attribute = attribute
      @name = attribute.name
      @child_plan = serializer ? SeregaPlan.new(serializer, self, modifiers || FROZEN_EMPTY_HASH) : nil
      @collection_classes = @child_plan ? {}.compare_by_identity : nil
    end

    # Attribute `many` option
    # @see SeregaAttribute#many
    def many
      attribute.many
    end

    # Attribute `serializer` option
    # @see SeregaAttribute#serializer
    def serializer
      attribute.serializer
    end

    # Attribute `batch_loaders`
    # @see SeregaAttribute#batch_loaders
    def batch_loaders
      attribute.batch_loaders
    end

    # Attribute `preloads`
    # @see SeregaAttribute#preloads
    def preloads
      attribute.preloads
    end

    # Attribute `conditional?`
    # @see SeregaAttribute#conditional?
    def conditional?
      attribute.conditional?
    end
  end
end
