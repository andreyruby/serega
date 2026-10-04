# frozen_string_literal: true

class Serega
  #
  # Constructs plan - list of serialized attributes.
  # We will traverse this plan to construct serialized response.
  #
  # @private
  class SeregaPlan
    #
    # SeregaPlan class methods
    #
    # @private
    module ClassMethods
      #
      # Returns (and caches) the Data class for the given set of field names.
      # Uses the Array as cache key so the same Data class is reused across
      # all plan instances with identical fields.
      #
      # @param point_names [Array<Symbol>] Attribute names for the Data members
      # @return [Class] Subclass of Data
      #
      def data_class_for(point_names)
        (@data_classes ||= {})[point_names] ||= Data.define(*point_names)
      end
    end

    #
    # SeregaPlan instance methods
    #
    # @private
    module InstanceMethods
      # Parent plan point
      # @return [SeregaPlanPoint, nil]
      attr_reader :parent_plan_point

      # Serialization points
      # @return [Array<SeregaPlanPoint>] points to serialize
      attr_reader :points

      # Serialization points with child plans
      # @return [Array<SeregaPlanPoint>] points to serialize with nested serializers
      attr_reader :relation_points

      #
      # Instantiate new serialization plan
      #
      # Patched by
      #  - depth_limit plugin, which checks depth limit is not exceeded when adding new plan
      #
      # @param parent_plan_point [SeregaPlanPoint, nil] Parent plan_point
      # @param modifiers [Hash] Serialization parameters
      # @option modifiers [Hash] :only The only attributes to serialize
      # @option modifiers [Hash] :except Attributes to hide
      # @option modifiers [Hash] :with Hidden attributes to serialize additionally
      #
      # @return [SeregaPlan] Serialization plan
      #
      def initialize(parent_plan_point, modifiers)
        serializer_class.lock
        @parent_plan_point = parent_plan_point
        @points = attributes_points(modifiers)
        @relation_points = points.select(&:child_plan).freeze
      end

      #
      # Serializer class of current plan
      #
      def serializer_class
        self.class.serializer_class
      end

      # Returns the Data class whose members match this plan's serialized fields.
      # Delegates to the class-level cache so identical field sets share one Data class.
      #
      # @return [Class] Subclass of Data
      #
      def data_class
        @data_class ||= self.class.data_class_for(point_names)
      end

      private

      def attributes_points(modifiers)
        only = modifiers[:only] || FROZEN_EMPTY_HASH
        except = modifiers[:except] || FROZEN_EMPTY_HASH
        with = modifiers[:with] || FROZEN_EMPTY_HASH
        points = []

        serializer_class.attributes.each_value do |attribute|
          next unless attribute.visible?(only: only, except: except, with: with)

          child_fields =
            if attribute.relation?
              name = attribute.name
              {only: only[name], with: with[name], except: except[name]}
            end

          point = serializer_class::SeregaPlanPoint.new(self, attribute, child_fields)
          points << point.freeze
        end

        points.freeze
      end

      def point_names
        @point_names ||= points.map(&:name)
      end
    end

    extend ClassMethods
    include InstanceMethods
    extend SeregaHelpers::SerializerClassHelper
  end
end
