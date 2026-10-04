# frozen_string_literal: true

class Serega
  #
  # Shape of serialization results of one plan in one serialization mode.
  #
  # The shape generates Ruby code of a builder. The builder makes the results
  # of a level in one loop. It reads all values of an object, then makes its
  # result in one step: a Hash literal, `Struct.new` or `Data.new`. The code
  # calls simple attribute readers directly, for example `object.name`.
  #
  # Generated code for a plan with `attribute :id` and
  # `attribute :posts, serializer: PostSerializer` in the :hash mode:
  #
  #   def call(objects, context, batches, relations)
  #     points = @points
  #     result_class = @result_class
  #     skip = Serega::SeregaEngine::SKIP
  #     attribute_0 = points[0].attribute
  #     batches_0 = batches && batches[0]
  #     relation_values_1 = relations[0]
  #     size = objects.size
  #     results = Array.new(size)
  #     object_index = 0
  #     point_index = nil
  #     while object_index < size
  #       object = objects[object_index]
  #       point_index = 0
  #       value_0 = object.id
  #       point_index = 1
  #       value_1 = relation_values_1[object_index]
  #       result = {:id => value_0, :posts => value_1}
  #       results[object_index] = result
  #       object_index += 1
  #     end
  #     results
  #   rescue => error
  #     raise unless point_index
  #
  #     Serega::SeregaUtils::SerializedAttributeError.call(error, points[point_index])
  #   end
  #
  # @private
  class SeregaResultShape
    @data_classes = {}
    @struct_classes = {}
    @builders = {}

    # Maximum count of cached builders per serializer
    MAX_BUILDERS = 1000

    # Method names called directly in generated code
    PLAIN_METHOD_NAME = /\A[a-z_][a-zA-Z0-9_]*[?!]?\z/

    #
    # SeregaResultShape class methods
    #
    # @private
    module ClassMethods
      #
      # Returns (and caches) the Data class for the given set of field names.
      #
      # @param point_names [Array<Symbol>] Attribute names for the Data members
      # @return [Class] Subclass of Data
      #
      def data_class_for(point_names)
        @data_classes[point_names] ||= Data.define(*point_names)
      end

      #
      # Returns (and caches) the Struct class for the given set of field names.
      #
      # @param point_names [Array<Symbol>] Attribute names for the Struct members
      # @return [Class] Subclass of Struct
      #
      def struct_class_for(point_names)
        @struct_classes[point_names] ||= Struct.new(*point_names)
      end

      #
      # Returns (and caches) the builder of results of the points.
      #
      # Points of different plans with the same attributes get the same
      # builder, thus a serializer generates the code once per set of
      # attributes and mode. When the cache is full, the oldest builder is
      # removed.
      #
      # @param mode [Symbol] Serialization mode - :hash, :data or :struct
      # @param points [Array<SeregaPlanPoint>] Serialized plan points
      #
      # @return [Object] Builder with the generated `#call(objects, context, batches, relations)` method
      #
      def builder(mode, points)
        key = points.map(&:attribute) << mode
        builders = @builders
        builders[key] || begin
          builders.shift if builders.size >= MAX_BUILDERS
          builders[key] = new(mode, points).builder
        end
      end

      private

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@data_classes, {})
        subclass.instance_variable_set(:@struct_classes, {})
        subclass.instance_variable_set(:@builders, {})
      end
    end

    #
    # SeregaResultShape instance methods
    #
    # @private
    module InstanceMethods
      # Serialization mode
      # @return [Symbol] :hash, :data or :struct
      attr_reader :mode

      #
      # Instantiates new result shape
      #
      # @param mode [Symbol] Serialization mode - :hash, :data or :struct
      # @param points [Array<SeregaPlanPoint>] Serialized plan points
      #
      def initialize(mode, points)
        @mode = mode
        @points = points
      end

      #
      # Generates the builder of results.
      #
      # @return [Object] Builder with the generated `#call(objects, context, batches, relations)` method
      #
      def builder
        builder_class = Class.new
        builder_class.class_eval(builder_code, __FILE__, __LINE__)
        builder = builder_class.allocate
        builder.instance_variable_set(:@points, @points)
        builder.instance_variable_set(:@result_class, result_class)
        builder
      end

      private

      def result_class
        case mode
        when :struct then self.class.struct_class_for(@points.map(&:name))
        when :data then self.class.data_class_for(@points.map(&:name))
        end
      end

      # The code of the `#call` method. The method has local variables for
      # every point, and they have the point index in their names:
      # - `attribute_N` and `batches_N` read values with `SeregaAttribute#value`.
      # - `relation_values_N` holds the built relation values of all objects.
      # - `point_N` checks the conditions of the :if plugin.
      # - `value_N` holds the value of the current object.
      # `point_index` holds the index of the point that reads a value now.
      # It adds the attribute name to the message of an error.
      def builder_code
        relation_index = -1
        variables_code = []
        values_code = []

        @points.each_with_index do |point, index|
          if point.child_plan
            relation_index += 1
            variables_code << "relation_values_#{index} = relations[#{relation_index}]"
          else
            variables_code << "attribute_#{index} = points[#{index}].attribute"
            variables_code << "batches_#{index} = batches && batches[#{index}]"
          end
          variables_code << "point_#{index} = points[#{index}]" if skippable?(point)

          values_code << "point_index = #{index}"
          values_code << assign_value_code(point, index)
        end

        <<~RUBY
          def call(objects, context, batches, relations)
            points = @points
            result_class = @result_class
            skip = Serega::SeregaEngine::SKIP
            #{variables_code.join("\n")}
            size = objects.size
            results = Array.new(size)
            object_index = 0
            point_index = nil
            while object_index < size
              object = objects[object_index]
              #{values_code.join("\n")}
              #{build_result_code}
              object_index += 1
            end
            results
          rescue => error
            raise unless point_index

            Serega::SeregaUtils::SerializedAttributeError.call(error, points[point_index])
          end
        RUBY
      end

      # Code that assigns the value of the point to `value_N`
      #
      # Patched in:
      # - plugin :if (assigns SKIP to values failing :if/:unless/:if_value/:unless_value conditions)
      def assign_value_code(point, index)
        "value_#{index} = #{read_value_code(point, index)}"
      end

      # Code that reads the value of the point
      def read_value_code(point, index)
        return "relation_values_#{index}[object_index]" if point.child_plan

        point.attribute.value_code("object") || "attribute_#{index}.value(object, context, batches: batches_#{index})"
      end

      # Whether the point value can be SKIP
      #
      # Patched in:
      # - plugin :if (conditional attributes can be skipped)
      def skippable?(_point)
        false
      end

      # Code that builds the result of the object.
      # A Struct or Data result gets nil for a skipped value.
      def build_result_code
        return build_hash_code if mode == :hash

        arguments = @points.each_with_index.map do |point, index|
          skippable?(point) ? "(skip.equal?(value_#{index}) ? nil : value_#{index})" : "value_#{index}"
        end

        "results[object_index] = result_class.new(#{arguments.join(", ")})"
      end

      # Code that builds the Hash result of the object.
      # A Hash literal holds the values up to the first skippable value. Then
      # the code adds the other values one by one, thus the Hash keys keep the
      # order of the points, and a skipped value adds no key.
      def build_hash_code
        literal_size = @points.index { |point| skippable?(point) } || @points.size
        pairs = @points.first(literal_size).each_with_index.map { |point, index| "#{point.name.inspect} => value_#{index}" }
        code = ["result = {#{pairs.join(", ")}}"]

        @points.each_with_index.drop(literal_size).each do |point, index|
          assign = "result[#{point.name.inspect}] = value_#{index}"
          code << (skippable?(point) ? "#{assign} unless skip.equal?(value_#{index})" : assign)
        end

        code << "results[object_index] = result"
        code.join("\n")
      end
    end

    extend ClassMethods
    include InstanceMethods
    extend SeregaHelpers::SerializerClassHelper
  end
end
