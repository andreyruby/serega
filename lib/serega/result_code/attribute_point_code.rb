# frozen_string_literal: true

class Serega
  class SeregaResultCode # :nodoc:
    #
    # Code of a point without a child plan. A plain attribute reads its value
    # with the SeregaAttribute::ValueCode#plain of its attribute, an
    # attribute with a `:value` callable calls it with the
    # SeregaAttribute::ValueCode#callable, other attributes call
    # SeregaAttribute#value.
    #
    class AttributePointCode < PointCode # :nodoc:
      def initialize(point, index)
        super
        @batches_variable = point.batch_loaders.empty? ? nil : "batches_#{index}"
        @callable_code = point.attribute.value_code.callable("callable_#{index}", @batches_variable || "nil", "SeregaAttributeValues::")
      end

      # Code that sets the local variables that the value code reads
      def variables
        index = @index
        variables = []
        if @callable_code
          variables << "callable_#{index} = @points[#{index}].attribute.value_callable"
        elsif !@point.attribute.value_method
          variables << "attribute_#{index} = @points[#{index}].attribute"
        end
        variables << "#{@batches_variable} = batches[#{index}]" if @batches_variable
        variables << "conditions_#{index} = @points[#{index}].attribute.conditions" if conditional?
        variables
      end

      # Code that assigns the value of the source to `value_N`. A
      # conditional attribute gets SKIP when it fails its conditions.
      def assign_value
        index = @index
        read_code = rescued_read_code
        return "value_#{index} =\n#{read_code.gsub(/^/, "  ")}" unless conditional?

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

      # An attribute without batch loaders reads one source alone, thus
      # `#call_one` can read it
      def call_one?
        !@batches_variable
      end

      private

      # Code that reads the value. An error raised there gets the attribute
      # name. Only the rescue reads the point.
      def rescued_read_code
        <<~RUBY.chomp
          begin
            #{read_value_code}
          rescue => error
            Serega::SeregaUtils::SerializedAttributeError.call(error, @points[#{@index}])
          end
        RUBY
      end

      # Code that reads the value. A plain attribute reads its `:const`,
      # `:default` and formatter values from the constants of
      # SeregaAttributeValues.
      def read_value_code
        attribute = @point.attribute
        return attribute.value_code.plain("SeregaAttributeValues::") if attribute.value_method
        return @callable_code if @callable_code
        return "attribute_#{@index}.value(source, context)" unless @batches_variable

        "attribute_#{@index}.value(source, context, batches: #{@batches_variable})"
      end
    end
  end
end
