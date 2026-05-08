# frozen_string_literal: true

class Serega
  #
  # Constructs plan - list of serialized attributes.
  # We will traverse this plan to construct serialized response.
  #
  class SeregaPlan
    #
    # SeregaPlan class methods
    #
    module ClassMethods
      #
      # Constructs plan of attributes that should be serialized.
      #
      # @param opts Serialization parameters
      # @option opts [Hash] :only The only attributes to serialize
      # @option opts [Hash] :except Attributes to hide
      # @option opts [Hash] :with Attributes (usually marked `hide: true`) to serialize additionally
      #
      # @return [SeregaPlan] Serialization plan
      #
      def call(opts)
        max_cache_size = serializer_class.config.max_cached_plans_per_serializer_count
        return new(nil, opts) if max_cache_size.zero?

        cached_plan_for(opts, max_cache_size)
      end

      #
      # Returns (and caches) the Data class for the given set of field names.
      # Uses the Array as cache key so the same Data class is reused across
      # all plan instances with identical fields.
      #
      # @param point_names [Array<Symbol>] Attribute names for the Data members
      # @return [Class] Subclass of Data
      #
      def data_class_for(point_names)
        (@data_classes ||= {})[point_names] ||= Data.define(*point_names)
      end

      private

      def cached_plan_for(opts, max_cache_size)
        @cache ||= {}
        cache_key = construct_cache_key(opts)

        plan = @cache[cache_key] ||= new(nil, opts)
        @cache.shift if @cache.length > max_cache_size
        plan
      end

      def construct_cache_key(opts, cache_key = nil)
        return nil if opts.empty?

        cache_key ||= +""

        opts.each do |key, nested_opts|
          cache_key.insert(-1, SeregaUtils::SymbolName.call(key))
          cache_key.insert(-1, "-")
          construct_cache_key(nested_opts, cache_key)
        end

        cache_key
      end
    end

    #
    # SeregaPlan instance methods
    #
    module InstanceMethods
      # Shows if plan includes batch points
      # @return [Array<SeregaPlanPoint>] points to serialize
      attr_reader :has_batch_points

      # Parent plan point
      # @return [SeregaPlanPoint, nil]
      attr_reader :parent_plan_point

      # Serialization points
      # @return [Array<SeregaPlanPoint>] points to serialize
      attr_reader :points

      # Named serialization points
      # @return [Hash] Named points
      attr_reader :points_hash

      #
      # Instantiate new serialization plan
      #
      # Patched by
      #  - depth_limit plugin, which checks depth limit is not exceeded when adding new plan
      #
      # @param parent_plan_point [SeregaPlanPoint, nil] Parent plan_point
      # @param modifiers [Hash] Serialization parameters
      # @option modifiers [Hash] :only The only attributes to serialize
      # @option modifiers [Hash] :except Attributes to hide
      # @option modifiers [Hash] :with Hidden attributes to serialize additionally
      #
      # @return [SeregaPlan] Serialization plan
      #
      def initialize(parent_plan_point, modifiers)
        @has_batch_points = false # should be before assigning points, generated points can change this attribute
        @parent_plan_point = parent_plan_point
        @points = attributes_points(modifiers)
        @points_hash = points.to_h { |point| [point.name, point] }
      end

      #
      # Serializer class of current plan
      #
      def serializer_class
        self.class.serializer_class
      end

      # Returns the Data class whose members match this plan's serialized fields.
      # Delegates to the class-level cache so identical field sets share one Data class.
      #
      # @return [Class] Subclass of Data
      #
      def data_class
        @data_class ||= self.class.data_class_for(point_names)
      end

      #
      # Marks current plan and top-level plans as `has_batch_points`
      # It is needed to initialize Batch Attribute Loaders when serialization starts
      #
      def mark_as_has_batch_points
        return if has_batch_points

        @has_batch_points = true
        parent_plan_point.plan.mark_as_has_batch_points if parent_plan_point # rubocop:disable Style/SafeNavigation
      end

      private

      def attributes_points(modifiers)
        only = modifiers[:only] || FROZEN_EMPTY_HASH
        except = modifiers[:except] || FROZEN_EMPTY_HASH
        with = modifiers[:with] || FROZEN_EMPTY_HASH
        points = []

        serializer_class.attributes.each_value do |attribute|
          next unless attribute.visible?(only: only, except: except, with: with)

          child_fields =
            if attribute.relation?
              name = attribute.name
              {only: only[name], with: with[name], except: except[name]}
            end

          point = serializer_class::SeregaPlanPoint.new(self, attribute, child_fields)
          points << point.freeze
        end

        points.freeze
      end

      def point_names
        @point_names ||= points.map(&:name)
      end
    end

    extend ClassMethods
    include InstanceMethods
    extend SeregaHelpers::SerializerClassHelper
  end
end
