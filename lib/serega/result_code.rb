# frozen_string_literal: true

class Serega
  #
  # Generates the Ruby code of the `SeregaResultBuilder#call` method of one
  # plan in one serialization mode. The method reads all values of a source,
  # then makes its serialized object in one step: a Hash literal,
  # `Struct.new` or `Data.new`. The code reads plain attributes directly,
  # for example `source.name`.
  #
  # Points without relations and batch loaders get a `#call_one(source,
  # context)` method too. It returns the serialized object of one source,
  # without the Array and the loop of `#call`.
  #
  # Generated code for a plan with `attribute :id` and
  # `attribute :posts, serializer: PostSerializer` in the :hash mode:
  #
  #   def call(sources, context, batches, relations)
  #     relation_values_1 = relations[@points[1]]
  #     size = sources.size
  #     serialized = Array.new(size)
  #     source_index = 0
  #     while source_index < size
  #       source = sources[source_index]
  #       value_0 =
  #         begin
  #           source.id
  #         rescue => error
  #           Serega::SeregaUtils::SerializedAttributeError.call(error, @points[0])
  #         end
  #       value_1 = relation_values_1[source_index]
  #       serialized[source_index] = {:id => value_0, :posts => value_1}
  #       source_index += 1
  #     end
  #     serialized
  #   end
  #
  class SeregaResultCode # :nodoc:
    # Method names called directly in generated code
    PLAIN_METHOD_NAME = /\A[a-z_][a-zA-Z0-9_]*[?!]?\z/

    # Serialization mode
    attr_reader :mode

    def initialize(mode, points)
      @mode = mode
      @point_codes = points.each_with_index.map do |point, index|
        point.child_plan ? RelationPointCode.new(point, index) : AttributePointCode.new(point, index)
      end
    end

    # Returns the code of the `#call` method, and of the `#call_one`
    # method for points without relations and batch loaders. The methods
    # have local variables for the points, and they have the point index
    # in their names:
    # - `attribute_N` and `batches_N` read values with `SeregaAttribute#value`.
    # - `conditions_N` checks the conditions of a conditional attribute.
    # - `relation_values_N` holds the relation values of all sources.
    # - `value_N` holds the value of the current source.
    def to_s
      variables = variables_code.join("\n  ")
      values = values_code
      code = call_code(variables, values)
      return code unless @point_codes.all?(&:call_one?)

      "#{code}\n#{call_one_code(variables, values)}"
    end

    private

    # A `while` loop fills an Array made with the size of the sources: no
    # block call and no Array growth per source.
    def call_code(variables, values)
      <<~RUBY
        def call(sources, context, batches, relations)
          #{variables}
          size = sources.size
          serialized = Array.new(size)
          source_index = 0
          while source_index < size
            source = sources[source_index]
            #{[*values, *build_serialized_code("serialized[source_index] = ")].join("\n").gsub("\n", "\n    ")}
            source_index += 1
          end
          serialized
        end
      RUBY
    end

    def call_one_code(variables, values)
      <<~RUBY
        def call_one(source, context)
          #{variables}
          #{[*values, *build_serialized_code("")].join("\n").gsub("\n", "\n  ")}
        end
      RUBY
    end

    # Code that sets the local variables of a method: only the variables
    # that the code of the points reads
    def variables_code
      point_variables = @point_codes.flat_map(&:variables)
      return point_variables if mode == :hash

      ["result_class = @result_class", *point_variables]
    end

    # Code that reads all values of the source, one entry per point
    def values_code
      @point_codes.map(&:assign_value)
    end

    # Code that builds the serialized object of the source. `assign` is the
    # code that takes the serialized object, empty for the return value.
    def build_serialized_code(assign)
      return build_serialized_hash_code(assign) if mode == :hash

      arguments = @point_codes.map(&:argument)
      ["#{assign}result_class.new(#{arguments.join(", ")})"]
    end

    # Code that builds the serialized Hash of the source, after `assign`.
    # A Hash literal holds the values up to the first conditional value. Then
    # the code adds the other values one by one, thus the Hash keys keep the
    # order of the points.
    def build_serialized_hash_code(assign)
      size = @point_codes.size
      literal_size = @point_codes.index(&:conditional?) || size
      pairs = @point_codes.first(literal_size).map(&:hash_pair)
      literal = "{#{pairs.join(", ")}}"
      return ["#{assign}#{literal}"] if literal_size == size

      assigns = @point_codes.drop(literal_size).map(&:hash_assign)
      ["serialized_hash = #{literal}", *assigns, "#{assign}serialized_hash"]
    end
  end
end
