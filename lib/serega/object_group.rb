# frozen_string_literal: true

class Serega
  #
  # All objects that one plan serializes in one run, for example the posts of
  # all users.
  #
  # The group serializes its objects in two steps:
  # - `#discover` runs the preloads, reads the relation values and adds the
  #   related objects to the groups of the relation plans.
  # - `#build` builds the results. It runs after the groups of the relation
  #   plans are built, thus the relation values are ready.
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

      # @return [Array<Hash, Struct, Data>, nil] Result per object, after #build
      attr_reader :results

      # @param run [SeregaEngine::Run] Serialization run
      # @param plan [SeregaPlan] Serialization plan
      def initialize(run, plan)
        @run = run
        @plan = plan
        @context = run.context
        @presenter = self.class.serializer_class.presenter
        @objects = []
        @relation_references = nil
        @results = nil
        @loaded_batches = {}.compare_by_identity
      end

      # Adds the object(s) to the group.
      #
      # @param object [Object] Serialized object(s)
      # @param many [Boolean, nil] Whether the object is a collection
      #
      # @return [Integer, Range, nil] Reference to the results: index for one
      #   object, range for a collection, or nil for nil
      def add(object, many)
        return if object.nil?

        case serialize_mode(object, many)
        when :many
          objects = object.to_a
          first_index = add_objects(objects)
          first_index...(first_index + objects.size)
        when :many_for_one # `many` on, but a sole object was given — wrap it, don't raise
          first_index = add_objects([object])
          first_index...(first_index + 1)
        else add_objects([object]) # :one
        end
      end

      # Runs the preloads, and adds the related objects to the groups of the
      # relation plans.
      #
      # @return [void]
      def discover
        objects = @objects

        plan.points.each do |point|
          point.run_preloads(objects) if point.preloads
        end

        relation_points = plan.relation_points
        return if relation_points.empty?

        @relation_references = relation_points.map do |point|
          batches = point.load_batches(self) unless point.batch_loaders.empty?
          child_group = run.object_group(point.child_plan)
          references = read_relations(point, batches, child_group)
          [child_group, references]
        end
      end

      # Builds the results of all objects. Fills a result container per
      # object, one point at a time. Relation values come from the built
      # child groups.
      #
      # @return [void]
      def build
        result_builder = plan.result_builder(run.mode)
        objects = @objects
        containers = result_builder.build_containers(objects.size)
        relation_references = @relation_references
        relation_index = -1

        plan.points.each do |point|
          if point.child_plan
            relation_index += 1
            child_group, references = relation_references[relation_index]
            values = relation_values(child_group.results, references)
            assign_relation_values(point, values, containers)
          else
            batches = point.load_batches(self) unless point.batch_loaders.empty?
            serialize_point(point, objects, containers, batches)
          end
        end

        @results = result_builder.build(containers)
      end

      # Loads a named batch loader once for all objects of the group.
      #
      # @param loader [SeregaBatchLoader] Named batch loader
      # @return [Object] Loaded values
      def load_batch(loader)
        @loaded_batches[loader] ||= loader.load(@objects, @context)
      end

      private

      # Adds objects and returns the index of the first one.
      #
      # Each object is wrapped in the serializer's presenter, so value reading
      # and batch loaders alike see presenters.
      def add_objects(objects)
        presenter = @presenter
        objects = objects.map { |object| presenter.new(object, context) } if presenter
        first_index = @objects.size
        @objects.concat(objects)
        first_index
      end

      # Reads the value of one point for every object and assigns it to the
      # object's container.
      #
      # Patched in:
      # - plugin :if (skips objects and values failing :if/:unless/:if_value/:unless_value conditions)
      def serialize_point(point, objects, containers, batches)
        attribute = point.attribute
        name = point.name
        context = @context
        index = 0
        size = objects.size

        while index < size
          containers[index][name] = attribute.value(objects[index], context, batches: batches)
          index += 1
        end
      rescue => error
        SeregaUtils::SerializedAttributeError.call(error, point)
      end

      # Assigns the relation values to the containers.
      #
      # Patched in:
      # - plugin :if (skips relations of objects failing :if/:unless conditions)
      def assign_relation_values(point, values, containers)
        name = point.name

        values.each_with_index do |value, index|
          containers[index][name] = value
        end
      end

      # Reads the relation value of every object, and adds the related objects
      # to the child group.
      #
      # Patched in:
      # - plugin :if (skips objects failing :if/:unless conditions)
      #
      # @return [Array] Result reference per object
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

      # Converts result references to relation values. An index takes one
      # child result, and a range takes an Array of child results. Other
      # references (nil, or a plugin value) stay as they are.
      def relation_values(child_results, references)
        references.map do |reference|
          case reference
          when Integer, Range then child_results[reference]
          else reference
          end
        end
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
