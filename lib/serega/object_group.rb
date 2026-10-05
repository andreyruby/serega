# frozen_string_literal: true

class Serega
  #
  # All objects that one plan serializes in one run, for example the posts of
  # all users.
  #
  # The group serializes its objects in two steps:
  # - `#discover` runs the preloads, reads the relation values and adds one
  #   child group of related objects per relation.
  # - `#build` builds the serialized objects (Hash, Struct or Data). It runs
  #   after the groups of the relation plans are built, thus the relation
  #   values are ready.
  #
  # @private
  class SeregaObjectGroup
    #
    # SeregaObjectGroup instance methods
    #
    # @private
    module InstanceMethods
      # @return [SeregaEngine::Run] Serialization run
      attr_reader :run

      # @return [SeregaPlan] Serialization plan
      attr_reader :plan

      # @return [Hash] Serialization context
      attr_reader :context

      # @return [Array] Objects to serialize (or their presenters)
      attr_reader :objects

      # @return [Array<Hash, Struct, Data>, nil] Serialized object per object,
      #   after #build
      attr_reader :serialized

      # @return [Array<Integer, nil, Object>] References from `Run#collect`,
      #   one per object of the parent group
      attr_reader :references

      # Each object is wrapped in the serializer's presenter, so value reading
      # and batch loaders alike see presenters.
      #
      # @param run [SeregaEngine::Run] Serialization run
      # @param plan [SeregaPlan] Serialization plan
      # @param objects [Array] Objects to serialize
      # @param references [Array<Integer, nil, Object>] References from
      #   `Run#collect`, one per object of the parent group
      def initialize(run, plan, objects, references)
        @run = run
        @plan = plan
        @context = run.context
        presenter = self.class.serializer_class.presenter
        @objects = presenter ? objects.map { |object| presenter.new(object, @context) } : objects
        @references = references
        @child_groups = nil
        @serialized = nil
        @loaded_batches = {}.compare_by_identity
      end

      # Runs the preloads, and adds one child group of related objects per
      # relation point.
      #
      # @return [void]
      def discover
        run_preloads

        plan.relation_points.each do |point|
          child_objects = []
          references = read_relations(point, batches_for(point), child_objects)
          child_group = run.add_object_group(point.child_plan, child_objects, references)
          child_groups = (@child_groups ||= {}.compare_by_identity)
          child_groups[point] = child_group
        end
      end

      # Builds the serialized objects.
      #
      # @return [void]
      def build
        batches = plan.points.map { |point| batches_for(point) } if plan.batch_points?
        relations = @child_groups&.transform_values(&:relation_values)
        @serialized = plan.result_builder(run.mode).call(@objects, @context, batches, relations)
      end

      # Returns the relation value of each object of the parent group. The
      # serialized objects follow the order of the references, thus the
      # method takes them one after another:
      # - SINGLE_OBJECT takes one serialized object.
      # - A count takes an Array of this count of serialized objects.
      # - Other references (nil, or a plugin value) stay as they are.
      #
      # @return [Array] Relation value per object of the parent group
      def relation_values
        serialized = @serialized
        single_object = SeregaEngine::SINGLE_OBJECT
        next_index = 0

        @references.map do |reference|
          case reference
          when single_object
            next_index += 1
            serialized[next_index - 1]
          when Integer
            next_index += reference
            serialized[next_index - reference, reference]
          else reference
          end
        end
      end

      private

      # Runs the preloads of all points with the serializer's preload handler.
      # Preload handlers get the objects without presenters.
      def run_preloads
        points = plan.preload_points
        return if points.empty?

        serializer_class = self.class.serializer_class
        handler = serializer_class.preload_with
        objects = serializer_class.presenter ? @objects.map(&:__getobj__) : @objects

        points.each do |point|
          unless handler
            raise SeregaError, "The :preload option requires a preload handler. Register one with `preload_with` (the :activerecord_preloads plugin does this for you)."
          end

          handler.call(objects, point.preloads)
        rescue => error
          SeregaUtils::SerializedAttributeError.call(error, point)
        end
      end

      # Loads the batch loaders of the point, each once for all objects of
      # the group.
      #
      # @return [Hash, nil] Loaded values per loader name, or nil when the
      #   point has no batch loaders
      def batches_for(point)
        names = point.batch_loaders
        return if names.empty?

        loaders = self.class.serializer_class.batch_loaders
        loaded_batches = @loaded_batches
        names.to_h do |name|
          loader = loaders[name]
          [name, loaded_batches[loader] ||= loader.load(@objects, @context)]
        end
      rescue => error
        SeregaUtils::SerializedAttributeError.call(error, point)
      end

      # Reads the relation value of every object, and adds the related objects
      # to child_objects.
      #
      # Patched in:
      # - plugin :if (skips objects failing :if/:unless conditions)
      #
      # @return [Array] Reference to the serialized related objects, per object
      def read_relations(point, batches, child_objects)
        attribute = point.attribute
        many = point.many
        context = @context
        run = @run

        @objects.map do |object|
          value = attribute.value(object, context, batches: batches)
          run.collect(value, many, child_objects)
        end
      rescue => error
        SeregaUtils::SerializedAttributeError.call(error, point)
      end
    end

    extend Serega::SeregaHelpers::SerializerClassHelper
    include InstanceMethods
  end
end
