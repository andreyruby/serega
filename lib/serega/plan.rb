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

    # Instantiate new serialization plan. Raises DepthLimitError when the plan
    # nests deeper than the depth limit of the root serializer.
    def initialize(serializer_class, parent_plan_point, modifiers)
      check_depth_limit(parent_plan_point) if parent_plan_point
      serializer_class.lock
      @serializer_class = serializer_class
      @parent_plan_point = parent_plan_point
      @points = attributes_points(modifiers)
      @relation_points = points.select(&:child_plan).freeze
      @preload_points = points.select(&:preloads).freeze
      @batch_points = points.any? { |point| !point.batch_loaders.empty? }
      @flat = relation_points.empty? && preload_points.empty? && !@batch_points && !serializer_class.presenter
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
    # Its sources need no source groups. YJIT reads an attr_reader without
    # a method call, and the alias keeps it.
    attr_reader :flat
    alias_method :flat?, :flat
    private :flat

    # Result builder of this plan in the serialization mode
    def result_builder(mode)
      @result_builders[mode] ||= SeregaResultBuilder.build(serializer_class, mode, points)
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

    def attributes_points(modifiers)
      only = modifiers[:only] || FROZEN_EMPTY_HASH
      except = modifiers[:except] || FROZEN_EMPTY_HASH
      with = modifiers[:with] || FROZEN_EMPTY_HASH
      only_limits = only_limits?(only, except, with)
      points = []

      serializer_class.attributes.each_value do |attribute|
        next unless attribute.visible?(only, except, with, only_limits)

        child_fields =
          if attribute.relation?
            name = attribute.name
            {only: only[name], with: with[name], except: except[name]}
          end

        point = SeregaPlanPoint.new(self, attribute, child_fields)
        points << point.freeze
      end

      points.freeze
    end

    # `only` hides the fields it does not name when it names a field of
    # this level without nested fields, or when `except` hides no field and
    # `with` adds no field of this level
    def only_limits?(only, except, with)
      return false if only.empty?
      return true if only.each_value.any?(&:empty?)

      with.empty? && except.each_value.none?(&:empty?)
    end
  end
end
