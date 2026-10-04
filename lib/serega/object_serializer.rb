# frozen_string_literal: true

class Serega
  #
  # Low-level class used by the serializer to construct the serialized response.
  #
  # Serialization goes level by level, in two passes:
  # - `#discover` runs the preloads of a level, reads its relation values and
  #   adds the related objects as a child level.
  # - `#build` builds the results of a level. It runs after the child levels
  #   are built, thus the relation values are ready.
  #
  # @private
  class SeregaObjectSerializer
    #
    # SeregaObjectSerializer instance methods
    #
    # @private
    module InstanceMethods
      # Reference to the result of one object. A reference to the results of a
      # collection is the count of its objects.
      SINGLE_OBJECT = -1

      attr_reader :context, :plan, :many, :level_queue, :presenter

      # @param plan [SeregaPlan] Serialization plan
      # @param context [Hash] Serialization context
      # @param level_queue [SeregaEngine::LevelQueue] Queue of serialization levels
      # @param many [Boolean] is object is enumerable
      #
      # @return [SeregaObjectSerializer] New SeregaObjectSerializer
      def initialize(context:, plan:, level_queue:, many: nil)
        @context = context
        @plan = plan
        @level_queue = level_queue
        @many = many
        # Looked up once here and reused for every level.
        @presenter = self.class.serializer_class.presenter
      end

      # Serializes the root object(s). Adds the root level and runs the level queue.
      #
      # @param object [Object] Serialized object(s)
      #
      # @return [Hash, Struct, Data, Array, nil] Serialized object(s)
      def serialize(object)
        objects = []
        reference = collect(object, objects)
        return if reference.nil?

        level = level_queue.add(self, wrap(objects))
        level_queue.run
        results = level.results
        (reference == SINGLE_OBJECT) ? results[0] : results
      end

      # Adds the serialized object(s) to the objects list.
      #
      # @param object [Object] Serialized object(s)
      # @param objects [Array] Objects list
      #
      # @return [Integer, nil] Reference to the results: SINGLE_OBJECT, count of
      #   objects of a collection, or nil for nil
      def collect(object, objects)
        return if object.nil?

        if many != false && object.instance_of?(Array)
          objects.concat(object)
          return object.size
        end

        case serialize_mode(object)
        when :many
          collection = object.to_a
          objects.concat(collection)
          collection.size
        when :many_for_one # `many` on, but a sole object was given — wrap it, don't raise
          objects << object
          1
        else # :one
          objects << object
          SINGLE_OBJECT
        end
      end

      # Wraps objects in the serializer's presenter, so the whole level — value
      # resolution and batch loaders alike — sees presenters.
      #
      # @param objects [Array] Serialized objects
      # @return [Array] Objects or presenters
      def wrap(objects)
        presenter ? objects.map { |object| presenter.new(object, context) } : objects
      end

      # Runs the preloads of one level and adds a child level per relation.
      #
      # @param level [SeregaEngine::Level] level to discover
      # @return [Array<Array(SeregaEngine::Level, Array)>, nil] child level and
      #   result references per relation point
      def discover(level)
        objects = level.objects

        plan.preload_points.each { |point| point.run_preloads(objects) }

        relation_points = plan.relation_points
        return if relation_points.empty?

        relation_points.map do |point|
          batches = point.load_batches(level) unless point.batch_loaders.empty?
          child_serializer = point.child_serializer(context: context, level_queue: level_queue)
          child_objects = []
          references = read_relations(point, objects, batches, child_serializer, child_objects)
          child_level = level_queue.add(child_serializer, child_serializer.wrap(child_objects))
          [child_level, references]
        end
      end

      # Builds the results of one level.
      #
      # @param level [SeregaEngine::Level] level to build
      # @param mode [Symbol] Serialization mode - :hash, :data or :struct
      # @param relation_references [Array, nil] child level and result references per relation point
      # @return [Array<Hash, Struct, Data>] results aligned with objects
      def build(level, mode, relation_references)
        batches = plan.points.map { |point| point.load_batches(level) unless point.batch_loaders.empty? } if plan.batch_points?
        relations = relation_references&.map { |child_level, references| relation_values(child_level.results, references) }
        plan.builder(mode).call(level.objects, context, batches, relations)
      end

      private

      # Reads the relation value of every object of the level, and adds the
      # related objects to child_objects.
      #
      # Patched in:
      # - plugin :if (skips objects failing :if/:unless conditions)
      #
      # @return [Array] Result reference per object
      def read_relations(point, objects, batches, child_serializer, child_objects)
        attribute = point.attribute
        context = @context

        objects.map do |object|
          value = attribute.value(object, context, batches: batches)
          child_serializer.collect(value, child_objects)
        end
      rescue => error
        SeregaUtils::SerializedAttributeError.call(error, point)
      end

      # Converts result references to relation values.
      #
      # The child results follow the order of the references, thus the method
      # takes them one after another:
      # - SINGLE_OBJECT takes one result.
      # - A count takes an Array of this count of results.
      # - nil and SKIP stay as they are.
      def relation_values(child_results, references)
        skip = SeregaEngine::SKIP
        next_result_index = 0

        references.map do |reference|
          if reference.nil? || skip.equal?(reference)
            reference
          elsif reference == SINGLE_OBJECT
            next_result_index += 1
            child_results[next_result_index - 1]
          else
            next_result_index += reference
            child_results[next_result_index - reference, reference]
          end
        end
      end

      # How to serialize `object`, deciding whether the result is a collection or a
      # single object and checking the object type only once:
      # - :many         — `many` is on and the object is a collection
      # - :many_for_one — `many` is on but a sole object was given (wrap it, don't raise)
      # - :one          — serialize the object on its own
      def serialize_mode(object)
        case many
        when NilClass then SeregaUtils::CollectionDetector.call(object) ? :many : :one
        when TrueClass then SeregaUtils::CollectionDetector.call(object) ? :many : :many_for_one
        else :one # many == false
        end
      end
    end

    extend Serega::SeregaHelpers::SerializerClassHelper
    include InstanceMethods
  end
end
