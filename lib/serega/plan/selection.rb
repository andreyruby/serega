# frozen_string_literal: true

class Serega
  class SeregaPlan # :nodoc:
    #
    # The attributes a plan serializes, selected with the parsed `only`,
    # `with` and `except` modifiers. A plan reads the selected attributes,
    # the selection of each child plan from `#child`, and the preloads of
    # each point from `#preloads`.
    #
    class Selection # :nodoc:
      # Serializer of the selected attributes
      attr_reader :serializer_class

      # Selects the attributes of the serializer with the parsed modifiers,
      # Hashes of attribute names
      def initialize(serializer_class, modifiers)
        @serializer_class = serializer_class
        @only = modifiers[:only] || FROZEN_EMPTY_HASH
        @with = modifiers[:with] || FROZEN_EMPTY_HASH
        @except = modifiers[:except] || FROZEN_EMPTY_HASH
      end

      # Returns the selected attributes, in definition order. Reads the
      # attributes on each call: the plan calls it once, after it locks the
      # serializer.
      def attributes
        only = @only
        with = @with
        except = @except
        only_limits = only_limits?
        attributes = []

        serializer_class.attributes.each_value do |attribute|
          attributes << attribute if attribute.visible?(only, except, with, only_limits)
        end

        attributes.freeze
      end

      # Returns the selection of the child plan of a selected attribute: the
      # relation serializer with the modifiers of the relation. Returns nil
      # for an attribute without a child plan.
      def child(attribute)
        return unless attribute.relation?

        name = attribute.name
        Selection.new(attribute.serializer, {only: @only[name], with: @with[name], except: @except[name]})
      end

      # Returns the preloads of the point of a selected attribute: the
      # preloads of the attribute
      def preloads(attribute)
        attribute.preloads
      end

      private

      # `only` hides the fields it does not name when it names a field of
      # this level without nested fields, or when `except` hides no field and
      # `with` adds no field of this level
      def only_limits?
        only = @only
        return false if only.empty?
        return true if only.each_value.any?(&:empty?)

        @with.empty? && @except.each_value.none?(&:empty?)
      end
    end
  end
end
