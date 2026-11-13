# frozen_string_literal: true

class Serega
  class SeregaResultCode # :nodoc:
    #
    # Code of a point with a child plan. Its values are the relation values
    # of all sources, built by the child group. A relation value skipped by
    # the :if and :unless conditions is SKIP already. The :if_value and
    # :unless_value conditions check the serialized relation value.
    #
    # The point also writes its loop of the `#collect` method: it reads the
    # relation source of each source with the code of an AttributePointCode,
    # appends the sources of the relation source to `child_sources_N`, and
    # writes the pull of each source to `pulls_N`. See SeregaEngine::Pulls.
    #
    class RelationPointCode < PointCode # :nodoc:
      def initialize(point, index)
        super
        @source_code = AttributePointCode.new(point, index, check_value: false)
        conditions = point.attribute.conditions
        @check_value = conditions ? conditions.value_conditions? : false
      end

      # Code that sets the local variables of the relation values and the
      # value conditions
      def variables
        index = @index
        variables = ["relation_values_#{index} = relations[@points[#{index}]]"]
        variables << "conditions_#{index} = @points[#{index}].attribute.conditions" if @check_value
        variables
      end

      # Code that assigns the relation value of the source to `value_N`. A
      # value that fails the value conditions gets SKIP.
      def assign_value
        index = @index
        code = "value_#{index} = relation_values_#{index}[source_index]"
        return code unless @check_value

        "#{code}\n" \
          "value_#{index} = Serega::SeregaEngine::SKIP unless Serega::SeregaEngine::SKIP.equal?(value_#{index}) || " \
          "conditions_#{index}.satisfy_value?(value_#{index}, context)"
      end

      # A relation needs the source group, thus no `#call_one`
      def call_one?
        false
      end

      # Code of the `#collect` loop of the point
      def collect
        index = @index
        variables = [*@source_code.variables, "child_sources_#{index} = []"]
        variables << "collection_classes_#{index} = @points[#{index}].collection_classes" unless @point.many == false
        <<~RUBY.chomp
          #{variables.join("\n")}
          pulls_#{index} = Array.new(size)
          source_index = 0
          while source_index < size
            source = sources[source_index]
            #{@source_code.assign_value.gsub("\n", "\n  ")}
            pulls_#{index}[source_index] =
              #{pull_code.gsub("\n", "\n    ")}
            source_index += 1
          end
        RUBY
      end

      # Variables that `#collect` returns for the point
      def collected
        "child_sources_#{@index}, pulls_#{@index}"
      end

      private

      # Code that appends the sources of `value_N` to `child_sources_N` and
      # gives its pull, as SeregaEngine::Pulls.append does
      def pull_code
        index = @index
        <<~RUBY.chomp
          #{skip_branch}if value_#{index}.nil?
            nil
          #{collection_branch}else
            child_sources_#{index} << value_#{index}
            #{@point.many ? "1" : "Serega::SeregaEngine::Pulls::SINGLE_SOURCE"}
          end
        RUBY
      end

      # First branch of the pull code of a conditional relation: SKIP is the
      # pull of a skipped relation source
      def skip_branch
        "if Serega::SeregaEngine::SKIP.equal?(value_#{@index})\n  value_#{@index}\nels" if @source_code.conditional?
      end

      # Branch of the pull code that appends a collection, unless the
      # relation has `many: false`. An Array is checked inline, without the
      # call of SeregaUtils::CollectionDetector.
      def collection_branch
        return if @point.many == false

        index = @index
        <<~RUBY
          elsif value_#{index}.instance_of?(Array) || Serega::SeregaUtils::CollectionDetector.call(value_#{index}, collection_classes_#{index})
            collection = value_#{index}.to_a
            child_sources_#{index}.concat(collection)
            collection.size
        RUBY
      end
    end
  end
end
