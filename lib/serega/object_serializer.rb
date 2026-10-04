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
  # @private
  class SeregaObjectSerializer
    #
    # SeregaObjectSerializer instance methods
    #
    # @private
    module InstanceMethods
      attr_reader :context, :plan, :many, :opts, :level_queue, :presenter

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
        # Looked up once here and reused for every enqueued chunk of the level.
        @presenter = self.class.serializer_class.presenter
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
        containers = level.containers

        plan.points.each do |point|
          point.run_preloads(objects) if point.preloads
          batches = point.load_batches(level) unless point.batch_loaders.empty?
          child_serializer = point.child_serializer(context: context, **opts) if point.child_plan

          process_point(point, objects, containers, batches, child_serializer)
        end
      end

      private

      # Enqueues this chunk of objects onto the queue and returns their result
      # containers. This is where objects enter their level, so every object a
      # point resolves against and a batch loader receives has the same shape.
      #
      # Each object is wrapped in the serializer's presenter before it is enqueued,
      # so the whole level — value resolution and batch loaders alike — sees
      # presenters. Serializers without a presenter enqueue the objects as they
      # are — wrapping would only add overhead and break class checks
      # (object.is_a?, Hash === object) without changing anything.
      def enqueue(objects)
        objects = objects.map { |object| presenter.new(object, context) } if presenter

        level_queue.enqueue(self, objects)
      end

      # Resolves one point's value for every object of the level and assigns it
      # to the object's container.
      #
      # Patched in:
      # - plugin :if (skips objects and values failing :if/:unless/:if_value/:unless_value conditions)
      def process_point(point, objects, containers, batches, child_serializer)
        attribute = point.attribute
        name = point.name
        context = @context
        index = 0
        size = objects.size

        while index < size
          value = attribute.value(objects[index], context, batches: batches)
          containers[index][name] = child_serializer ? child_serializer.serialize(value) : value
          index += 1
        end
      rescue => error
        SeregaUtils::SerializedAttributeError.call(error, point)
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
