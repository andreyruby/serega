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

      # Adds the object(s) to the level of the plan.
      #
      # @param object [Object] Serialized object(s)
      #
      # @return [Integer, Range, nil] Reference to the results in the level:
      #   index for one object, range for a collection, or nil for nil
      def serialize(object)
        return if object.nil?

        case serialize_mode(object)
        when :many
          objects = object.to_a
          first_index = enqueue(objects)
          first_index...(first_index + objects.size)
        when :many_for_one # `many` on, but a sole object was given — wrap it, don't raise
          first_index = enqueue([object])
          first_index...(first_index + 1)
        else enqueue([object]) # :one
        end
      end

      # Runs the preloads of one level and adds the related objects to child levels.
      #
      # @param level [SeregaEngine::Level] level to discover
      # @return [Array<Array(SeregaEngine::Level, Array)>, nil] child level and
      #   result references per relation point
      def discover(level)
        objects = level.objects

        plan.points.each do |point|
          point.run_preloads(objects) if point.preloads
        end

        relation_points = plan.relation_points
        return if relation_points.empty?

        relation_points.map do |point|
          batches = point.load_batches(level) unless point.batch_loaders.empty?
          child_serializer = point.child_serializer(context: context, level_queue: level_queue)
          references = read_relations(point, objects, batches, child_serializer)
          [level_queue.level(child_serializer), references]
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

      # Adds objects to the level of the plan and returns the index of the
      # first one in the level.
      #
      # Each object is wrapped in the serializer's presenter, so the whole
      # level — value resolution and batch loaders alike — sees presenters.
      def enqueue(objects)
        objects = objects.map { |object| presenter.new(object, context) } if presenter

        level_queue.enqueue(self, objects)
      end

      # Reads the relation value of every object of the level, and adds the
      # related objects to the child level.
      #
      # Patched in:
      # - plugin :if (skips objects failing :if/:unless conditions)
      #
      # @return [Array] Result reference per object
      def read_relations(point, objects, batches, child_serializer)
        attribute = point.attribute
        context = @context

        objects.map do |object|
          value = attribute.value(object, context, batches: batches)
          child_serializer.serialize(value)
        end
      rescue => error
        SeregaUtils::SerializedAttributeError.call(error, point)
      end

      # Converts result references to relation values. An index takes one
      # child result, and a range takes an Array of child results. nil and
      # SKIP stay as they are.
      def relation_values(child_results, references)
        skip = SeregaEngine::SKIP

        references.map do |reference|
          (reference.nil? || skip.equal?(reference)) ? reference : child_results[reference]
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
