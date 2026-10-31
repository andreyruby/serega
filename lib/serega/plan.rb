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
    # selection's serializer, with the result builder class of the
    # selection. A child plan gets the point of its parent plan. Raises
    # DepthLimitError when the plan nests deeper than the depth limit of the
    # root serializer.
    def initialize(selection, parent_plan_point = nil)
      check_depth_limit(parent_plan_point) if parent_plan_point
      serializer_class = selection.serializer_class
      serializer_class.lock
      @serializer_class = serializer_class
      @parent_plan_point = parent_plan_point
      @presenter = serializer_class.local_presenter
      @builder_class = selection.builder_class
      @points = selected_points(selection)
      @relation_points = points.select(&:child_plan).freeze
      @preload_points = points.select(&:preloads).freeze
      @batch_points = points.any? { |point| !point.batch_loaders.empty? }
      @flat = relation_points.empty? && preload_points.empty? && !@batch_points && !@presenter
      @result_builders = {}
      @collection_classes = {}.compare_by_identity
      direct = parent_plan_point.nil? && @flat && !serializer_class.prepare_initial_objects_signature && @builder_class.equal?(SeregaResultBuilder)
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
    # initial objects and whose builder class is SeregaResultBuilder.
    # `Serega#call` builds one source with it directly.
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

    # Plan that starts the serialization: this plan, or the root plan of
    # its parent point
    def root_plan
      plan = self
      while (point = plan.parent_plan_point)
        plan = point.plan
      end
      plan
    end

    # Result builder of this plan in the serialization mode, made with the
    # builder class of the selection
    def result_builder(mode)
      @result_builders[mode] ||= @builder_class.new(serializer_class, mode, points)
    end

    private

    # A child plan is one level deeper than the path of its parent point
    def check_depth_limit(parent_plan_point)
      root_serializer = parent_plan_point.plan.root_plan.serializer_class
      limit = root_serializer.config.depth_limit
      return unless limit

      path = parent_plan_point.path
      return if path.size + 1 <= limit

      raise DepthLimitError.new("Depth limit was exceeded", "#{root_serializer} (depth limit: #{limit}) -> #{path.join(" -> ")}")
    end

    # Makes a point of each selected attribute, with the preloads and child
    # selection the selection gives it
    def selected_points(selection)
      points = selection.attributes.map do |attribute|
        Point.new(self, attribute, selection.preloads(attribute), selection.child(attribute)).freeze
      end

      points.freeze
    end
  end
end
