# frozen_string_literal: true

class Serega
  #
  # All sources that one plan serializes in one run, for example the posts of
  # all users. A source is an object to serialize. A serialized object is its
  # output: a Hash, Struct or Data object.
  #
  # The group serializes its sources in two steps:
  # - `#discover` runs the preloads, reads the relation sources with the
  #   generated `#collect` of the result builder and adds one child group per
  #   relation.
  # - `#build` builds the serialized objects. It runs after the child groups
  #   are built, thus the relation values are ready.
  #
  class SeregaSourceGroup # :nodoc:
    # Serialization run
    attr_reader :run

    # Serialization plan
    attr_reader :plan

    # Serialization context
    attr_reader :context

    # Sources (or their presenters)
    attr_reader :sources

    # Serialized object of each
    # source, after #build
    attr_reader :serialized

    # Pulls from the generated `#collect` of the parent group, one per
    # source of the parent group
    attr_reader :pulls

    # Each source is wrapped in the presenter of the plan, when it has one,
    # so value reading and batch loaders alike see presenters.
    def initialize(run, plan, sources, pulls)
      @run = run
      @plan = plan
      @context = run.context
      presenter = plan.presenter
      @sources = presenter ? sources.map { |source| presenter.new(source, @context) } : sources
      @pulls = pulls
      @child_groups = nil
      @serialized = nil
      @loaded_batches = nil
    end

    # Runs the preloads, and makes one child group per relation point, in the
    # order of the relation points. The generated `#collect` reads the
    # relation sources, and gives the child sources and the pulls of each
    # relation point.
    def discover
      run_preloads

      relation_points = plan.relation_points
      return FROZEN_EMPTY_ARRAY if relation_points.empty?

      collected = plan.result_builder(run.mode).collect(@sources, @context, relation_batches)
      @child_groups = child_groups(relation_points, collected)
    end

    # Builds the serialized objects.
    def build
      batches = plan.points.map { |point| batches_for(point) } if plan.batch_points?
      @serialized = plan.result_builder(run.mode).call(@sources, @context, batches, relations)
    end

    # Serialized value of a root group, after #build: one serialized object
    # for a SINGLE_SOURCE pull, or all serialized objects
    def root_value
      serialized = @serialized
      SeregaEngine::Pulls::SINGLE_SOURCE.equal?(@pulls[0]) ? serialized[0] : serialized
    end

    private

    # Relation values of each relation point, taken from its built child
    # group, or nil without relation points
    def relations
      child_groups = @child_groups
      return unless child_groups

      relation_points = plan.relation_points
      relations = {}
      index = 0

      while index < relation_points.size
        child_group = child_groups[index]
        relations[relation_points[index]] = SeregaEngine::Pulls.take!(child_group.serialized, child_group.pulls)
        index += 1
      end

      relations
    end

    # Runs the preloads of all points with the serializer's preload handler.
    # Preload handlers get the sources without presenters.
    def run_preloads
      points = plan.preload_points
      return if points.empty?

      serializer_class = plan.serializer_class
      handler = serializer_class.preload_with
      sources = plan.presenter ? @sources.map(&:__getobj__) : @sources

      points.each do |point|
        unless handler
          raise SeregaError, "The :preload option requires a preload handler. Register one with `preload_with` (the :activerecord_preloads plugin does this for you)."
        end

        handler.call(sources, point.preloads)
      rescue => error
        SeregaUtils::SerializedAttributeError.call(error, point)
      end
    end

    # One child group per relation point, with the child sources and the
    # pulls that `#collect` gave for it
    def child_groups(relation_points, collected)
      Array.new(relation_points.size) do |position|
        offset = position * 2
        run.new_source_group(relation_points[position].child_plan, collected[offset], collected[offset + 1])
      end
    end

    # Loaded batches of the relation points, by point index, or nil
    # without batch points. Other points load their batches in #build.
    def relation_batches
      return unless plan.batch_points?

      plan.points.map { |point| batches_for(point) if point.child_plan }
    end

    # Loads the batch loaders of the point, each once for all sources of
    # the group. An attribute with an inline batch loader uses it, other
    # attributes use the named batch loaders of the serializer. Returns nil
    # when the point has no batch loaders.
    def batches_for(point)
      names = point.batch_loaders
      return if names.empty?

      inline_loader = point.attribute.inline_batch_loader
      loaders = plan.serializer_class.batch_loaders
      loaded_batches = (@loaded_batches ||= {}.compare_by_identity)
      names.to_h do |name|
        loader = inline_loader || loaders[name]
        [name, loaded_batches[loader] ||= loader.load(@sources, @context)]
      end
    rescue => error
      SeregaUtils::SerializedAttributeError.call(error, point)
    end
  end
end
