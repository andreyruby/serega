# frozen_string_literal: true

class Serega
  #
  # All sources that one plan serializes in one run, for example the posts of
  # all users. A source is an object to serialize. A serialized object is its
  # output: a Hash, Struct or Data object.
  #
  # The group serializes its sources in two steps:
  # - `#discover` runs the preloads, reads the relation sources and adds one
  #   child group per relation.
  # - `#build` builds the serialized objects. It runs after the child groups
  #   are built, thus the relation values are ready.
  #
  # @private
  class SeregaSourceGroup
    #
    # SeregaSourceGroup class methods
    #
    # @private
    module ClassMethods
      #
      # Collects the sources of the relation sources, and the pull of each
      # relation source. #take_relation_values! uses the pulls to turn the
      # serialized objects into relation values.
      #
      # @param relation_sources [Array] Relation source of each source of the
      #   parent group: what the relation attribute returns
      # @param many [Boolean, nil] Whether a relation source is a collection
      #
      # @return [Array(Array, Array)] Sources, and the pull of each relation source
      #
      def collect(relation_sources, many)
        sources = []
        pulls = relation_sources.map { |relation_source| append_sources(sources, relation_source, many) }
        [sources, pulls]
      end

      #
      # Collects like `.collect`, and keeps SKIP of a skipped relation source
      # as its pull.
      #
      # @param relation_sources [Array] Relation source or SKIP of each source
      #   of the parent group
      # @param many [Boolean, nil] Whether a relation source is a collection
      #
      # @return [Array(Array, Array)] Sources, and the pull of each relation source
      #
      def collect_conditional(relation_sources, many)
        sources = []
        skip = SeregaEngine::SKIP
        pulls = relation_sources.map do |relation_source|
          skip.equal?(relation_source) ? skip : append_sources(sources, relation_source, many)
        end
        [sources, pulls]
      end

      #
      # Appends the source(s) of one relation source to sources, and returns
      # the pull: what #take_relation_values! takes for it from the serialized
      # objects.
      # - the count of a collection: an Array of this count of serialized objects
      # - SINGLE_SOURCE for one source: one serialized object
      # - nil for nil: nothing, the relation value is nil
      #
      # @param sources [Array] Sources list
      # @param relation_source [Object] Relation source, or the root source(s)
      # @param many [Boolean, nil] Whether the relation source is a collection
      #
      # @return [Integer, nil, Object] Pull
      #
      def append_sources(sources, relation_source, many)
        return if relation_source.nil?

        if many != false && SeregaUtils::CollectionDetector.call(relation_source)
          collection = relation_source.to_a
          sources.concat(collection)
          collection.size
        else
          sources << relation_source
          many ? 1 : SeregaEngine::SINGLE_SOURCE # `many` on, but a sole source was given — wrap it, don't raise
        end
      end
    end

    #
    # SeregaSourceGroup instance methods
    #
    # @private
    module InstanceMethods
      # @return [SeregaEngine::Run] Serialization run
      attr_reader :run

      # @return [SeregaPlan] Serialization plan
      attr_reader :plan

      # @return [Hash] Serialization context
      attr_reader :context

      # @return [Array] Sources (or their presenters)
      attr_reader :sources

      # @return [Array<Hash, Struct, Data>, nil] Serialized object of each
      #   source, after #build
      attr_reader :serialized

      # @return [Array<Integer, nil, Object>] Pulls from `.collect`, one per
      #   source of the parent group
      attr_reader :pulls

      # Each source is wrapped in the serializer's presenter, so value reading
      # and batch loaders alike see presenters.
      #
      # @param run [SeregaEngine::Run] Serialization run
      # @param plan [SeregaPlan] Serialization plan
      # @param sources [Array] Sources
      # @param pulls [Array<Integer, nil, Object>] Pulls from `.collect`, one
      #   per source of the parent group
      def initialize(run, plan, sources, pulls)
        @run = run
        @plan = plan
        @context = run.context
        presenter = self.class.serializer_class.presenter
        @sources = presenter ? sources.map { |source| presenter.new(source, @context) } : sources
        @pulls = pulls
        @child_groups = nil
        @serialized = nil
        @loaded_batches = nil
      end

      # Runs the preloads, and makes one child group per relation point.
      #
      # @return [Array<SeregaSourceGroup>] Child groups
      def discover
        run_preloads

        relation_points = plan.relation_points
        return FROZEN_EMPTY_ARRAY if relation_points.empty?

        @child_groups = relation_points.to_h { |point| [point, child_group(point)] }
        @child_groups.values
      end

      # Builds the serialized objects.
      #
      # @return [void]
      def build
        batches = plan.points.map { |point| batches_for(point) } if plan.batch_points?
        relations = @child_groups&.transform_values { |child_group| take_relation_values!(child_group) }
        @serialized = plan.result_builder(run.mode).call(@sources, @context, batches, relations)
      end

      private

      # Takes the relation value of each source from the front of the
      # serialized objects of the child group. The serialized objects follow
      # the order of the pulls, thus each pull takes the next ones. Empties
      # the serialized objects of the child group.
      def take_relation_values!(child_group)
        serialized = child_group.serialized
        child_group.pulls.map { |pull| pull_value(serialized, pull) }
      end

      # Takes the relation value of one pull from the front of the
      # serialized objects:
      # - a count: an Array of the next serialized objects
      # - SINGLE_SOURCE: the next serialized object
      # - nil or SKIP: the pull itself
      def pull_value(serialized, pull)
        case pull
        when Integer then serialized.shift(pull)
        when SeregaEngine::SINGLE_SOURCE then serialized.shift
        else pull
        end
      end

      # Reads the relation sources of the point, and makes their child group
      def child_group(point)
        batches = batches_for(point)
        child_sources, pulls =
          if point.conditional?
            relation_sources = read_conditional_relation_sources(point, batches)
            self.class.collect_conditional(relation_sources, point.many)
          else
            relation_sources = read_relation_sources(point, batches)
            self.class.collect(relation_sources, point.many)
          end
        run.new_source_group(point.child_plan, child_sources, pulls)
      end

      # Runs the preloads of all points with the serializer's preload handler.
      # Preload handlers get the sources without presenters.
      def run_preloads
        points = plan.preload_points
        return if points.empty?

        serializer_class = self.class.serializer_class
        handler = serializer_class.preload_with
        sources = serializer_class.presenter ? @sources.map(&:__getobj__) : @sources

        points.each do |point|
          unless handler
            raise SeregaError, "The :preload option requires a preload handler. Register one with `preload_with` (the :activerecord_preloads plugin does this for you)."
          end

          handler.call(sources, point.preloads)
        rescue => error
          SeregaUtils::SerializedAttributeError.call(error, point)
        end
      end

      # Loads the batch loaders of the point, each once for all sources of
      # the group.
      #
      # @return [Hash, nil] Loaded values per loader name, or nil when the
      #   point has no batch loaders
      def batches_for(point)
        names = point.batch_loaders
        return if names.empty?

        loaders = self.class.serializer_class.batch_loaders
        loaded_batches = (@loaded_batches ||= {}.compare_by_identity)
        names.to_h do |name|
          loader = loaders[name]
          [name, loaded_batches[loader] ||= loader.load(@sources, @context)]
        end
      rescue => error
        SeregaUtils::SerializedAttributeError.call(error, point)
      end

      # Reads the relation source of every source: what the relation
      # attribute returns, for example `user.posts`.
      #
      # @return [Array] Relation source of each source
      def read_relation_sources(point, batches)
        attribute = point.attribute
        context = @context

        @sources.map { |source| attribute.value(source, context, batches: batches) }
      rescue => error
        SeregaUtils::SerializedAttributeError.call(error, point)
      end

      # Reads the relation source of every source of a conditional relation.
      # A source failing the :if or :unless condition gets SKIP.
      #
      # @return [Array] Relation source or SKIP of each source
      def read_conditional_relation_sources(point, batches)
        attribute = point.attribute
        context = @context
        skip = SeregaEngine::SKIP

        @sources.map do |source|
          next skip unless point.satisfy_if_conditions?(source, context)

          begin
            attribute.value(source, context, batches: batches)
          rescue => error
            SeregaUtils::SerializedAttributeError.call(error, point)
          end
        end
      end
    end

    extend Serega::SeregaHelpers::SerializerClassHelper
    extend ClassMethods
    include InstanceMethods
  end
end
