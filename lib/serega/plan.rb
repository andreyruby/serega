# frozen_string_literal: true

class Serega
  #
  # Constructs plan - list of serialized attributes.
  # We will traverse this plan to construct serialized response.
  #
  # @private
  class SeregaPlan
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
        @preload_points = points.select(&:preloads).freeze
        @batch_points = points.any? { |point| !point.batch_loaders.empty? }
        @flat = relation_points.empty? && preload_points.empty? && !@batch_points && !serializer_class.presenter
        @result_builders = {}
      # :nocov:
      rescue *RACTOR_ISOLATION_ERRORS
        raise if serializer_class.shareable?

        raise SeregaError, "#{serializer_class} can not serialize in other Ractors. Call `make_shareable!` at the end of its definition"
        # :nocov:
      end

      # Serialization points with preloads
      # @return [Array<SeregaPlanPoint>] points to run preloads for
      attr_reader :preload_points

      # @return [Boolean] Whether any point uses batch loaders
      def batch_points?
        @batch_points
      end

      # A flat plan has no relations, preloads, batch loaders and presenter.
      # Its sources need no source groups.
      #
      # @return [Boolean] Whether the plan is flat
      def flat?
        @flat
      end

      #
      # Serializer class of current plan
      #
      def serializer_class
        self.class.serializer_class
      end

      #
      # Result builder of this plan in the serialization mode
      #
      # @param mode [Symbol] Serialization mode - :hash, :data or :struct
      #
      # @return [SeregaResultBuilder] Result builder
      #
      def result_builder(mode)
        @result_builders[mode] ||= serializer_class::SeregaResultBuilder.new(mode, points)
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
    end

    include InstanceMethods
    extend SeregaHelpers::SerializerClassHelper
  end
end
