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
    # @return [Symbol] :hash, :data or :struct
    attr_reader :mode

    # @param mode [Symbol] Serialization mode - :hash, :data or :struct
    # @param points [Array<SeregaPlanPoint>] Serialized plan points
    def initialize(mode, points)
      @mode = mode
      @points = points
    end

    # Returns the code of the `#call` method, and of the `#call_one`
    # method for points without relations and batch loaders. The methods
    # have local variables for the points, and they have the point index
    # in their names:
    # - `attribute_N` and `batches_N` read values with `SeregaAttribute#value`.
    # - `conditions_N` checks the conditions of a conditional attribute.
    # - `relation_values_N` holds the relation values of all sources.
    # - `value_N` holds the value of the current source.
    #
    # @return [String] Code of the methods
    def to_s
      variables = variables_code.join("\n  ")
      values = values_code
      code = call_code(variables, values)
      return code unless @points.none? { |point| point.child_plan || !point.batch_loaders.empty? }

      "#{code}\n#{call_one_code(variables, values)}"
    end

    private

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
      point_variables = @points.each_with_index.flat_map { |point, index| point_variables_code(point, index) }
      return point_variables if mode == :hash

      ["result_class = @result_class", *point_variables]
    end

    def point_variables_code(point, index)
      return ["relation_values_#{index} = relations[@points[#{index}]]"] if point.child_plan

      variables = []
      variables << "attribute_#{index} = @points[#{index}].attribute" unless point.attribute.value_method
      variables << "batches_#{index} = batches[#{index}]" unless point.batch_loaders.empty?
      variables << "conditions_#{index} = @points[#{index}].attribute.conditions" if point.conditional?
      variables
    end

    # Code that reads all values of the source, one entry per point
    def values_code
      @points.each_with_index.map { |point, index| assign_value_code(point, index) }
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
          if conditions_#{index}.satisfy?(source, context)
            value_#{index} =
        #{read_code.gsub(/^/, "      ")}
            conditions_#{index}.satisfy_value?(value_#{index}, context) ? value_#{index} : Serega::SeregaEngine::SKIP
          else
            Serega::SeregaEngine::SKIP
          end
      RUBY
    end

    # Code that reads the value of the point. An error raised there gets
    # the attribute name. Only the rescue reads the point.
    def rescued_read_code(point, index)
      <<~RUBY.chomp
        begin
          #{read_value_code(point, index)}
        rescue => error
          Serega::SeregaUtils::SerializedAttributeError.call(error, @points[#{index}])
        end
      RUBY
    end

    # Code that reads the value of the point. A plain attribute reads its
    # `:const`, `:default` and formatter values from the constants of
    # SeregaAttributeValues.
    def read_value_code(point, index)
      return "relation_values_#{index}[source_index]" if point.child_plan

      attribute = point.attribute
      return attribute.value_code("source", "SeregaAttributeValues::") if attribute.value_method
      return "attribute_#{index}.value(source, context)" if point.batch_loaders.empty?

      "attribute_#{index}.value(source, context, batches: batches_#{index})"
    end

    # Code that builds the serialized object of the source. `assign` is the
    # code that takes the serialized object, empty for the return value.
    def build_serialized_code(assign)
      return build_serialized_hash_code(assign) if mode == :hash

      arguments = @points.each_index.map { |index| argument_code(index) }
      ["#{assign}result_class.new(#{arguments.join(", ")})"]
    end

    # Code of the Struct or Data argument with the value of the point, nil
    # for a skipped value
    def argument_code(index)
      return "value_#{index}" unless @points[index].conditional?

      "(Serega::SeregaEngine::SKIP.equal?(value_#{index}) ? nil : value_#{index})"
    end

    # Code that builds the serialized Hash of the source, after `assign`.
    # A Hash literal holds the values up to the first conditional value. Then
    # the code adds the other values one by one, thus the Hash keys keep the
    # order of the points.
    def build_serialized_hash_code(assign)
      literal_size = @points.index(&:conditional?) || @points.size
      pairs = @points.first(literal_size).each_with_index.map { |point, index| "#{point.name.inspect} => value_#{index}" }
      literal = "{#{pairs.join(", ")}}"
      return ["#{assign}#{literal}"] if literal_size == @points.size

      assigns = @points.each_with_index.drop(literal_size).map { |point, index| hash_assign_code(point, index) }
      ["serialized_hash = #{literal}", *assigns, "#{assign}serialized_hash"]
    end

    # Code that adds the value of the point to the serialized Hash. It adds
    # no key for a skipped value.
    def hash_assign_code(point, index)
      code = "serialized_hash[#{point.name.inspect}] = value_#{index}"
      point.conditional? ? "#{code} unless Serega::SeregaEngine::SKIP.equal?(value_#{index})" : code
    end
  end
end
