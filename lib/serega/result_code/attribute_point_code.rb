# frozen_string_literal: true

class Serega
  class SeregaResultCode # :nodoc:
    #
    # Code of a point without a child plan. A plain attribute reads its value
    # with the SeregaAttribute::ValueCode#plain of its attribute, an
    # attribute with a `:value` callable calls it with the
    # SeregaAttribute::ValueCode#callable, a :batch attribute reads its
    # loaded batch with the SeregaAttribute::ValueCode#batch, other
    # attributes call SeregaAttribute#value.
    #
    class AttributePointCode < PointCode # :nodoc:
      def initialize(point, index)
        super
        value_code = point.attribute.value_code
        @batch_code = value_code.batch("batch_#{index}", "SeregaAttributeValues::")
        @batches_variable = (point.batch_loaders.empty? || @batch_code) ? nil : "batches_#{index}"
        @callable_code = value_code.callable("callable_#{index}", @batches_variable || "nil", "SeregaAttributeValues::")
        @read_code = value_code.plain("SeregaAttributeValues::") || @callable_code || @batch_code
      end

      # Code that sets the local variables that the value code reads
      def variables
        index = @index
        variables = [value_variable]
        variables << "#{@batches_variable} = batches[#{index}]" if @batches_variable
        variables << "conditions_#{index} = @points[#{index}].attribute.conditions" if conditional?
        variables.compact
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
        @point.batch_loaders.empty?
      end

      private

      # Code that sets the variable that reads the value: the callable, the
      # loaded batch of the only loader, or the attribute. nil for a plain
      # attribute, which reads the source alone.
      def value_variable
        index = @index
        return "callable_#{index} = @points[#{index}].attribute.value_callable" if @callable_code
        return "batch_#{index} = batches[#{index}].fetch(#{@point.batch_loaders.first.inspect})" if @batch_code

        "attribute_#{index} = @points[#{index}].attribute" unless @read_code
      end

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

      # Code that reads the value: the code of the plain value, the
      # callable or the loaded batch, or a SeregaAttribute#value call. The
      # code reads the `:const`, `:default` and formatter values from the
      # constants of SeregaAttributeValues.
      def read_value_code
        read_code = @read_code
        return read_code if read_code
        return "attribute_#{@index}.value(source, context)" unless @batches_variable

        "attribute_#{@index}.value(source, context, batches: #{@batches_variable})"
      end
    end
  end
end
