# frozen_string_literal: true

class Serega
  #
  # Constructs plan - list of serialized attributes.
  # We will traverse this plan to construct serialized response.
  #
  class SeregaPlan # :nodoc:
    # Serializer of the plan
    attr_reader :serializer_class

    # Parent plan point
    attr_reader :parent_plan_point

    # Serialization points
    attr_reader :points

    # Serialization points with child plans
    attr_reader :relation_points

    # Whether the root objects of a class are collections
    attr_reader :collection_classes

    # Presenter class that wraps the sources in the Ractor of the plan, `nil`
    # without presenter methods
    attr_reader :presenter

    # Instantiate new serialization plan of the selected attributes of the
    # selection's serializer. A child plan gets the point of its parent plan.
    # Raises DepthLimitError when the plan nests deeper than the depth limit
    # of the root serializer.
    def initialize(selection, parent_plan_point = nil)
      check_depth_limit(parent_plan_point) if parent_plan_point
      serializer_class = selection.serializer_class
      serializer_class.lock
      @serializer_class = serializer_class
      @parent_plan_point = parent_plan_point
      @presenter = serializer_class.local_presenter
      @points = selected_points(selection)
      @relation_points = points.select(&:child_plan).freeze
      @preload_points = points.select(&:preloads).freeze
      @batch_points = points.any? { |point| !point.batch_loaders.empty? }
      @flat = relation_points.empty? && preload_points.empty? && !@batch_points && !@presenter
      @result_builders = {}
      @collection_classes = {}.compare_by_identity
      direct = parent_plan_point.nil? && @flat && !serializer_class.prepare_initial_objects_signature
      @direct_hash_builder = direct ? result_builder(:hash) : nil
    # :nocov:
    rescue *RACTOR_ISOLATION_ERRORS
      raise if serializer_class.shareable?

      raise SeregaError, "#{serializer_class} can not serialize in other Ractors. Call `make_shareable!` at the end of its definition"
      # :nocov:
    end

    # Serialization points with preloads
    attr_reader :preload_points

    # Hash result builder of a flat root plan whose serializer prepares no
    # initial objects. `Serega#call` builds one source with it directly.
    attr_reader :direct_hash_builder

    # Whether any point uses batch loaders
    def batch_points?
      @batch_points
    end

    # A flat plan has no relations, preloads, batch loaders and presenter.
    # Its sources need no source groups.
    def flat?
      @flat
    end

    # Result builder of this plan in the serialization mode
    def result_builder(mode)
      @result_builders[mode] ||= SeregaResultBuilder.new(serializer_class, mode, points)
    end

    private

    def check_depth_limit(parent_plan_point)
      depth = 2
      root_plan = parent_plan_point.plan
      while (point = root_plan.parent_plan_point)
        depth += 1
        root_plan = point.plan
      end

      root_serializer = root_plan.serializer_class
      limit = root_serializer.config.depth_limit
      return if limit.nil? || depth <= limit

      names = [parent_plan_point.name]
      point = parent_plan_point
      names.unshift(point.name) while (point = point.plan.parent_plan_point)
      raise DepthLimitError.new("Depth limit was exceeded", "#{root_serializer} (depth limit: #{limit}) -> #{names.join(" -> ")}")
    end

    # Makes a point of each selected attribute, with the child selection of
    # the attribute for its child plan
    def selected_points(selection)
      points = selection.attributes.map do |attribute|
        Point.new(self, attribute, selection.child(attribute)).freeze
      end

      points.freeze
    end
  end
end
