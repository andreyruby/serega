# frozen_string_literal: true

class Serega
  #
  # Generates the Ruby code of the `SeregaResultBuilder#call` method of one
  # plan in one serialization mode. The method reads all values of a source,
  # then makes its serialized object in one step: a Hash literal,
  # `Struct.new` or `Data.new`. Simple attributes are read with their
  # SeregaAttributeValues method, for example `attribute_values.name(source)`.
  #
  # Generated code for a plan with `attribute :id` and
  # `attribute :posts, serializer: PostSerializer` in the :hash mode:
  #
  #   def call(sources, context, batches, relations)
  #     points = @points
  #     result_class = @result_class
  #     attribute_values = @attribute_values
  #     point_0 = points[0]
  #     attribute_0 = point_0.attribute
  #     batches_0 = batches && batches[0]
  #     relation_values_1 = relations[points[1]]
  #     size = sources.size
  #     serialized = Array.new(size)
  #     source_index = 0
  #     while source_index < size
  #       source = sources[source_index]
  #       value_0 =
  #         begin
  #           attribute_values.id(source)
  #         rescue => error
  #           Serega::SeregaUtils::SerializedAttributeError.call(error, point_0)
  #         end
  #       value_1 = relation_values_1[source_index]
  #       serialized_hash = {:id => value_0, :posts => value_1}
  #       serialized[source_index] = serialized_hash
  #       source_index += 1
  #     end
  #     serialized
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
      # - `point_N` holds the point. An error raised while its value is read
      #   gets the attribute name.
      # - `attribute_N` and `batches_N` read values with `SeregaAttribute#value`.
      # - `relation_values_N` holds the relation values of all sources.
      # - `value_N` holds the value of the current source.
      #
      # @return [String] Code of the `#call` method
      def to_s
        values_code = @points.each_with_index.map { |point, index| assign_value_code(point, index) }
        loop_code = [*values_code, build_serialized_code].join("\n")

        <<~RUBY
          def call(sources, context, batches, relations)
            #{variables_code.join("\n  ")}
            size = sources.size
            serialized = Array.new(size)
            source_index = 0
            while source_index < size
              source = sources[source_index]
              #{loop_code.gsub("\n", "\n    ")}
              source_index += 1
            end
            serialized
          end
        RUBY
      end

      private

      # Code that sets the local variables of the `#call` method
      def variables_code
        point_variables = @points.each_with_index.flat_map do |point, index|
          next ["relation_values_#{index} = relations[points[#{index}]]"] if point.child_plan

          ["point_#{index} = points[#{index}]", "attribute_#{index} = point_#{index}.attribute", "batches_#{index} = batches && batches[#{index}]"]
        end
        ["points = @points", "result_class = @result_class", "attribute_values = @attribute_values", *point_variables]
      end

      # Code that assigns the value of the point to `value_N`. A conditional
      # attribute gets SKIP when it fails its conditions. A conditional
      # relation value is SKIP already.
      def assign_value_code(point, index)
        return "value_#{index} = #{read_value_code(point, index)}" if point.child_plan

        read_code = rescued_read_code(point, index)
        return "value_#{index} =\n#{read_code.gsub(/^/, "  ")}" unless point.conditional?

        <<~RUBY.chomp
          value_#{index} =
            if point_#{index}.satisfy_if_conditions?(source, context)
              value_#{index} =
          #{read_code.gsub(/^/, "      ")}
              point_#{index}.satisfy_if_value_conditions?(value_#{index}, context) ? value_#{index} : Serega::SeregaEngine::SKIP
            else
              Serega::SeregaEngine::SKIP
            end
        RUBY
      end

      # Code that reads the value of the point. An error raised there gets
      # the attribute name.
      def rescued_read_code(point, index)
        <<~RUBY.chomp
          begin
            #{read_value_code(point, index)}
          rescue => error
            Serega::SeregaUtils::SerializedAttributeError.call(error, point_#{index})
          end
        RUBY
      end

      # Code that reads the value of the point
      def read_value_code(point, index)
        return "relation_values_#{index}[source_index]" if point.child_plan

        value_method = point.attribute.value_method
        return "attribute_#{index}.value(source, context, batches: batches_#{index})" unless value_method
        return "attribute_values.#{value_method}(source)" if PLAIN_METHOD_NAME.match?(value_method)

        "attribute_values.__send__(#{value_method.inspect}, source)"
      end

      # Code that builds the serialized object of the source
      def build_serialized_code
        return build_serialized_hash_code if mode == :hash

        arguments = @points.each_index.map { |index| argument_code(index) }
        "serialized[source_index] = result_class.new(#{arguments.join(", ")})"
      end

      # Code of the Struct or Data argument with the value of the point, nil
      # for a skipped value
      def argument_code(index)
        return "value_#{index}" unless @points[index].conditional?

        "(Serega::SeregaEngine::SKIP.equal?(value_#{index}) ? nil : value_#{index})"
      end

      # Code that builds the serialized Hash of the source.
      # A Hash literal holds the values up to the first conditional value. Then
      # the code adds the other values one by one, thus the Hash keys keep the
      # order of the points.
      def build_serialized_hash_code
        literal_size = @points.index(&:conditional?) || @points.size
        pairs = @points.first(literal_size).each_with_index.map { |point, index| "#{point.name.inspect} => value_#{index}" }
        assigns = @points.each_with_index.drop(literal_size).map { |point, index| hash_assign_code(point, index) }

        ["serialized_hash = {#{pairs.join(", ")}}", *assigns, "serialized[source_index] = serialized_hash"].join("\n")
      end

      # Code that adds the value of the point to the serialized Hash. It adds
      # no key for a skipped value.
      def hash_assign_code(point, index)
        code = "serialized_hash[#{point.name.inspect}] = value_#{index}"
        point.conditional? ? "#{code} unless Serega::SeregaEngine::SKIP.equal?(value_#{index})" : code
      end
    end

    include InstanceMethods
    extend SeregaHelpers::SerializerClassHelper
  end
end
