# frozen_string_literal: true

class Serega
  # @private
  module SeregaUtils
    #
    # Reraises an error, adding which attribute and serializer were being
    # serialized when it happened, and where the attribute is defined. Value
    # reads, preloads, batch loaders and attribute conditions use it.
    #
    # @private
    module SerializedAttributeError
      # File name of the generated code in backtraces
      GENERATED_CODE_FILE = "(serega generated code)"

      class << self
        #
        # Reraises an error raised while a value is read, preloaded or batch
        # loaded. An error raised in the generated code gets a backtrace line at
        # the attribute, above the line of the generated code:
        #
        #   app/serializers/user_serializer.rb:3:in 'attribute :full_name of UserSerializer'
        #   (serega generated code):20:in 'call'
        #
        # @param error [Exception] Original error
        # @param point [SeregaPlanPoint] Plan point being serialized
        #
        # @return [void]
        #
        def call(error, point)
          location = point.attribute.location
          serializer_class = point.plan.serializer_class
          defined_at = location ? ", #{location}" : ""

          exception = error.exception(<<~MESSAGE.strip)
            #{error.message}
            (when serializing the '#{point.name}' attribute in #{serializer_class}#{defined_at})
          MESSAGE
          add_attribute_line(exception, "#{location}:in 'attribute :#{point.name} of #{serializer_class}'") if location
          raise exception
        end

        #
        # Reraises an error raised by an :if, :unless, :if_value or
        # :unless_value condition
        #
        # @param error [Exception] Original error
        # @param attribute [SeregaAttribute] Attribute with the condition
        # @param condition_name [Symbol] Condition option name
        #
        # @return [void]
        #
        def condition(error, attribute, condition_name)
          location = attribute.location
          defined_at = location ? ", #{location}" : ""

          raise error.exception(<<~MESSAGE.strip)
            #{error.message}
            (when checking the :#{condition_name} condition of the '#{attribute.name}' attribute in #{attribute.serializer_class}#{defined_at})
          MESSAGE
        end

        private

        # Puts the line above the line of the generated code that called this
        # module. The backtrace and the call stack share the outer lines, up
        # to that line: the backtrace has the line of the read there, the
        # call stack the line of the rescue.
        def add_attribute_line(exception, line)
          backtrace = exception.backtrace
          return unless backtrace

          index = backtrace.size - shared_outer_lines_count(backtrace, caller(2)) - 1
          return if index.negative? || !backtrace[index].start_with?(GENERATED_CODE_FILE)

          exception.set_backtrace(backtrace.dup.insert(index, line))
        end

        def shared_outer_lines_count(backtrace, stack)
          count = 0
          count += 1 while count < backtrace.size && count < stack.size && backtrace[-1 - count] == stack[-1 - count]
          count
        end
      end
    end
  end
end
