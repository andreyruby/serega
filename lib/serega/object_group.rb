# frozen_string_literal: true

class Serega
  #
  # All objects that one plan serializes in one run, for example the posts of
  # all users.
  #
  # The group serializes its objects in two steps:
  # - `#discover` runs the preloads, reads the relation values and adds the
  #   related objects to the groups of the relation plans.
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

      # @param run [SeregaEngine::Run] Serialization run
      # @param plan [SeregaPlan] Serialization plan
      def initialize(run, plan)
        @run = run
        @plan = plan
        @context = run.context
        @presenter = self.class.serializer_class.presenter
        @objects = []
        @relation_references = nil
        @serialized = nil
        @loaded_batches = {}.compare_by_identity
      end

      # Adds the object(s) to the group.
      #
      # @param object [Object] Object(s) to serialize
      # @param many [Boolean, nil] Whether the object is a collection
      #
      # @return [Integer, Range, nil] Reference to the serialized objects:
      #   index for one object, range for a collection, or nil for nil
      def add(object, many)
        return if object.nil?

        first_index = @objects.size

        if many != false && SeregaUtils::CollectionDetector.call(object)
          add_objects(object.to_a)
          first_index...@objects.size
        elsif many # `many` on, but a sole object was given — wrap it, don't raise
          add_objects([object])
          first_index...@objects.size
        else
          add_objects([object])
          first_index
        end
      end

      # Runs the preloads, and adds the related objects to the groups of the
      # relation plans.
      #
      # @return [void]
      def discover
        run_preloads

        plan.relation_points.each do |point|
          child_group = run.object_group(point.child_plan)
          references = read_relations(point, batches_for(point), child_group)
          relation_references = (@relation_references ||= {}.compare_by_identity)
          relation_references[point] = [child_group, references]
        end
      end

      # Builds the serialized objects.
      #
      # @return [void]
      def build
        batches = plan.points.map { |point| batches_for(point) } if plan.batch_points?
        relations = @relation_references&.transform_values do |child_group, references|
          references.map { |reference| child_group.serialized_for(reference) }
        end
        @serialized = plan.result_builder(run.mode).call(@objects, @context, batches, relations)
      end

      # Returns the serialized object(s) of a reference from #add: one
      # serialized object for an index, an Array of them for a range. Other
      # references (nil, or a plugin value) stay as they are.
      #
      # @param reference [Integer, Range, Object] Reference from #add
      # @return [Hash, Struct, Data, Array, Object] Serialized object(s)
      def serialized_for(reference)
        case reference
        when Integer, Range then @serialized[reference]
        else reference
        end
      end

      private

      # Adds objects.
      #
      # Each object is wrapped in the serializer's presenter, so value reading
      # and batch loaders alike see presenters.
      def add_objects(objects)
        presenter = @presenter
        objects = objects.map { |object| presenter.new(object, context) } if presenter
        @objects.concat(objects)
      end

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
      # to the child group.
      #
      # Patched in:
      # - plugin :if (skips objects failing :if/:unless conditions)
      #
      # @return [Array] Reference to the serialized related objects, per object
      def read_relations(point, batches, child_group)
        attribute = point.attribute
        many = point.many
        context = @context

        @objects.map do |object|
          value = attribute.value(object, context, batches: batches)
          child_group.add(value, many)
        end
      rescue => error
        SeregaUtils::SerializedAttributeError.call(error, point)
      end
    end

    extend Serega::SeregaHelpers::SerializerClassHelper
    include InstanceMethods
  end
end
