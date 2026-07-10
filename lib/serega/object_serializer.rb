# frozen_string_literal: true

class Serega
  #
  # Low-level class used by the serializer to construct the serialized response.
  #
  # Serialization is level-by-level. `#serialize` builds the result container(s)
  # and enqueues this level; the batch queue later calls `#process` for each level,
  # which resolves every attribute for every object and enqueues child levels for
  # relations.
  #
  class SeregaObjectSerializer
    #
    # SeregaObjectSerializer instance methods
    #
    module InstanceMethods
      attr_reader :context, :plan, :many, :opts, :level_queue

      # @param plan [SeregaPlan] Serialization plan
      # @param context [Hash] Serialization context
      # @param many [Boolean] is object is enumerable
      # @param opts [Hash] Any custom options
      #
      # @return [SeregaObjectSerializer] New SeregaObjectSerializer
      def initialize(context:, plan:, many: nil, **opts)
        @context = context
        @plan = plan
        @many = many
        @opts = opts
        @level_queue = opts[:level_queue]
      end

      # Enqueues this level and returns its result container(s). The containers are
      # returned immediately but filled in place once the queue is processed.
      #
      # @param object [Object] Serialized object(s)
      #
      # @return [Hash, Array<Hash>, nil] Serialized object(s)
      def serialize(object)
        return if object.nil?

        case serialize_mode(object)
        when :many then enqueue(object.to_a)
        when :many_for_one then enqueue([object]) # `many` on, but a sole object was given — wrap it, don't raise
        else enqueue([object])[0] # :one
        end
      end

      # Resolves every attribute of one level onto its containers. For each point,
      # preloads and batch loaders run once over all of the level's objects; the
      # value is then resolved and assigned per object, in attribute order.
      #
      # @param level [SeregaEngine::Level] level to resolve
      # @return [void]
      def process(level)
        objects = level.objects

        plan.points.each do |point|
          point.run_preloads(objects)
          batches = point.load_batches(level)
          # One child serializer per relation point per level (reused for every object),
          # instead of one per object — child objects are grouped into one child level anyway.
          child_serializer = point.child_serializer(context: context, **opts)

          objects.each_with_index do |object, index|
            resolve_point(object, point, level.containers[index], batches, child_serializer)
          rescue => error
            SeregaUtils::SerializedAttributeError.call(error, point)
          end
        end
      end

      private

      # Enqueues this chunk of objects onto the queue and returns their result
      # containers. This is where objects enter their level, so every object a
      # point resolves against and a batch loader receives has the same shape.
      #
      # Patched in:
      # - plugin :presenter (wraps each object in a Presenter before enqueueing)
      def enqueue(objects)
        level_queue.enqueue(self, objects)
      end

      # Patched in:
      # - plugin :if (skips the point for objects failing an :if/:unless condition)
      def resolve_point(object, point, container, batches, child_serializer)
        value = point.value(object, context, batches: batches)
        final_value = child_serializer ? child_serializer.serialize(value) : value
        write_value(final_value, point, container)
      end

      # Patched in:
      # - plugin :if (skips assigning when an :if_value/:unless_value condition fails)
      def write_value(final_value, point, container)
        container[point.name] = final_value
      end

      # How to serialize `object`, deciding whether the result is a collection or a
      # single object and checking the object type only once:
      # - :many         — `many` is on and the object is a collection
      # - :many_for_one — `many` is on but a sole object was given (wrap it, don't raise)
      # - :one          — serialize the object on its own
      def serialize_mode(object)
        case many
        when NilClass then SeregaUtils::Collection.call(object) ? :many : :one
        when TrueClass then SeregaUtils::Collection.call(object) ? :many : :many_for_one
        else :one # many == false
        end
      end
    end

    extend Serega::SeregaHelpers::SerializerClassHelper
    include InstanceMethods
  end
end
