# frozen_string_literal: true

class Serega
  #
  # Generates the Ruby code of the `SeregaResultBuilder#call` method of one
  # plan in one serialization mode. The method reads all values of an
  # object, then makes the serialized object in one step: a Hash literal,
  # `Struct.new` or `Data.new`. The code calls simple attribute readers
  # directly, for example `object.name`.
  #
  # Generated code for a plan with `attribute :id` and
  # `attribute :posts, serializer: PostSerializer` in the :hash mode:
  #
  #   def call(objects, context, batches, relations)
  #     points = @points
  #     result_class = @result_class
  #     attribute_0 = points[0].attribute
  #     batches_0 = batches && batches[0]
  #     relation_values_1 = relations[points[1]]
  #     size = objects.size
  #     serialized = Array.new(size)
  #     object_index = 0
  #     point_index = nil
  #     while object_index < size
  #       object = objects[object_index]
  #       point_index = 0
  #       value_0 = object.id
  #       point_index = 1
  #       value_1 = relation_values_1[object_index]
  #       serialized_hash = {:id => value_0, :posts => value_1}
  #       serialized[object_index] = serialized_hash
  #       object_index += 1
  #     end
  #     serialized
  #   rescue => error
  #     raise unless point_index
  #
  #     Serega::SeregaUtils::SerializedAttributeError.call(error, points[point_index])
  #   end
  #
  # @private
  class SeregaResultCode
    # Method names called directly in generated code
    PLAIN_METHOD_NAME = /\A[a-z_][a-zA-Z0-9_]*[?!]?\z/

    #
    # SeregaResultCode instance methods
    #
    # @private
    module InstanceMethods
      # Serialization mode
      # @return [Symbol] :hash, :data or :struct
      attr_reader :mode

      # @param mode [Symbol] Serialization mode - :hash, :data or :struct
      # @param points [Array<SeregaPlanPoint>] Serialized plan points
      def initialize(mode, points)
        @mode = mode
        @points = points
      end

      # Returns the code of the `#call` method. The method has local
      # variables for every point, and they have the point index in their
      # names:
      # - `attribute_N` and `batches_N` read values with `SeregaAttribute#value`.
      # - `relation_values_N` holds the relation values of all objects.
      # - `value_N` holds the value of the current object.
      # `point_index` holds the index of the point that reads a value now.
      # It adds the attribute name to the message of an error.
      #
      # @return [String] Code of the `#call` method
      def to_s
        values_code = []

        @points.each_with_index do |point, index|
          values_code << "point_index = #{index}"
          values_code << assign_value_code(point, index)
        end

        <<~RUBY
          def call(objects, context, batches, relations)
            #{variables_code.join("\n")}
            size = objects.size
            serialized = Array.new(size)
            object_index = 0
            point_index = nil
            while object_index < size
              object = objects[object_index]
              #{values_code.join("\n")}
              #{build_serialized_code}
              object_index += 1
            end
            serialized
          rescue => error
            raise unless point_index

            Serega::SeregaUtils::SerializedAttributeError.call(error, points[point_index])
          end
        RUBY
      end

      private

      # Code that sets the local variables of the `#call` method
      #
      # Patched in:
      # - plugin :if (adds the variables that check the conditions)
      def variables_code
        code = ["points = @points", "result_class = @result_class"]

        @points.each_with_index do |point, index|
          if point.child_plan
            code << "relation_values_#{index} = relations[points[#{index}]]"
          else
            code << "attribute_#{index} = points[#{index}].attribute"
            code << "batches_#{index} = batches && batches[#{index}]"
          end
        end

        code
      end

      # Code that assigns the value of the point to `value_N`
      #
      # Patched in:
      # - plugin :if (skips values failing :if/:unless/:if_value/:unless_value conditions)
      def assign_value_code(point, index)
        "value_#{index} = #{read_value_code(point, index)}"
      end

      # Code that reads the value of the point
      def read_value_code(point, index)
        return "relation_values_#{index}[object_index]" if point.child_plan

        point.attribute.value_code("object") || "attribute_#{index}.value(object, context, batches: batches_#{index})"
      end

      # Whether the point value can be skipped
      #
      # Patched in:
      # - plugin :if (conditional attributes can be skipped)
      def skippable?(_point)
        false
      end

      # Code that builds the serialized object
      def build_serialized_code
        return build_serialized_hash_code if mode == :hash

        arguments = @points.each_index.map { |index| argument_code(index) }
        "serialized[object_index] = result_class.new(#{arguments.join(", ")})"
      end

      # Code of the Struct or Data argument with the value of the point
      #
      # Patched in:
      # - plugin :if (nil for a skipped value)
      def argument_code(index)
        "value_#{index}"
      end

      # Code that builds the serialized Hash of the object.
      # A Hash literal holds the values up to the first skippable value. Then
      # the code adds the other values one by one, thus the Hash keys keep the
      # order of the points.
      def build_serialized_hash_code
        literal_size = @points.index { |point| skippable?(point) } || @points.size
        pairs = @points.first(literal_size).each_with_index.map { |point, index| "#{point.name.inspect} => value_#{index}" }
        code = ["serialized_hash = {#{pairs.join(", ")}}"]

        @points.each_with_index.drop(literal_size).each do |point, index|
          code << hash_assign_code(point, index)
        end

        code << "serialized[object_index] = serialized_hash"
        code.join("\n")
      end

      # Code that adds the value of the point to the serialized Hash
      #
      # Patched in:
      # - plugin :if (adds no key for a skipped value)
      def hash_assign_code(point, index)
        "serialized_hash[#{point.name.inspect}] = value_#{index}"
      end
    end

    include InstanceMethods
    extend SeregaHelpers::SerializerClassHelper
  end
end
