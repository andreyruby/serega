# frozen_string_literal: true

class Serega
  class SeregaResultCode # :nodoc:
    #
    # Code of a point with a child plan. Its values are the relation values
    # of all sources, built by the child group. A conditional relation value
    # is SKIP already.
    #
    class RelationPointCode < PointCode # :nodoc:
      # Code that sets the local variable of the relation values
      def variables
        ["relation_values_#{@index} = relations[@points[#{@index}]]"]
      end

      # Code that assigns the relation value of the source to `value_N`
      def assign_value
        "value_#{@index} = relation_values_#{@index}[source_index]"
      end

      # A relation needs the source group, thus no `#call_one`
      def call_one?
        false
      end
    end
  end
end
