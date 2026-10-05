# frozen_string_literal: true

class Serega
  #
  # All objects that one plan serializes in one run, for example the posts of
  # all users. Each object has a result container.
  #
  # `#add` adds objects and returns their empty containers. `#serialize` fills
  # the containers later. It reads each attribute for all objects, thus batch
  # loaders and preloads run once per group. Related objects go to the group
  # of the relation plan.
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

      # @return [Array] Serialized objects (or their presenters)
      attr_reader :objects

      # @return [Array<Hash, Struct>] Result container per object
      attr_reader :containers

      # @param run [SeregaEngine::Run] Serialization run
      # @param plan [SeregaPlan] Serialization plan
      def initialize(run, plan)
        @run = run
        @plan = plan
        @context = run.context
        @presenter = self.class.serializer_class.presenter
        @result_builder = plan.result_builder(run.mode)
        @objects = []
        @containers = []
        @loaded_batches = {}.compare_by_identity
      end

      # Adds the object(s) to the group.
      #
      # @param object [Object] Serialized object(s)
      # @param many [Boolean, nil] Whether the object is a collection
      #
      # @return [Hash, Struct, Array, nil] Empty result container(s), filled in
      #   place by #serialize
      def add(object, many)
        return if object.nil?

        case serialize_mode(object, many)
        when :many then add_objects(object.to_a)
        when :many_for_one then add_objects([object]) # `many` on, but a sole object was given — wrap it, don't raise
        else add_objects([object])[0] # :one
        end
      end

      # Fills the containers of all objects. For each point, preloads and batch
      # loaders run once over all objects; the value is then read and assigned
      # per object, in attribute order.
      #
      # @return [void]
      def serialize
        objects = @objects
        containers = @containers

        plan.points.each do |point|
          point.run_preloads(objects) if point.preloads
          batches = point.load_batches(self) unless point.batch_loaders.empty?
          child_group = run.object_group(point.child_plan) if point.child_plan

          serialize_point(point, objects, containers, batches, child_group)
        end
      end

      # Loads a named batch loader once for all objects of the group.
      #
      # @param loader [SeregaBatchLoader] Named batch loader
      # @return [Object] Loaded values
      def load_batch(loader)
        @loaded_batches[loader] ||= loader.load(@objects, @context)
      end

      private

      # Adds objects and returns their new containers.
      #
      # Each object is wrapped in the serializer's presenter, so value reading
      # and batch loaders alike see presenters.
      def add_objects(objects)
        presenter = @presenter
        objects = objects.map { |object| presenter.new(object, context) } if presenter
        containers = @result_builder.build_containers(objects.size)
        @objects.concat(objects)
        @containers.concat(containers)
        containers
      end

      # Reads the value of one point for every object and assigns it to the
      # object's container. Related objects go to the child group.
      #
      # Patched in:
      # - plugin :if (skips objects and values failing :if/:unless/:if_value/:unless_value conditions)
      def serialize_point(point, objects, containers, batches, child_group)
        attribute = point.attribute
        name = point.name
        many = point.many
        context = @context
        index = 0
        size = objects.size

        while index < size
          value = attribute.value(objects[index], context, batches: batches)
          containers[index][name] = child_group ? child_group.add(value, many) : value
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
      def serialize_mode(object, many)
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
