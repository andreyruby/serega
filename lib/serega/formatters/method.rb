# frozen_string_literal: true

class Serega
  module SeregaFormatters # :nodoc:
    #
    # Formatter that calls a method of the value, for example `[:round, 2]`
    #
    class Method # :nodoc:
      # Arguments of the method
      attr_reader :args

      def initialize(use, allow_nil)
        method_name, *args = use
        @method_name = method_name
        @args = args
        @allow_nil = allow_nil
      end

      # A method formatter has no callable
      def callable
      end

      # Formats the value
      def call(value, _context)
        return if value.nil? && @allow_nil

        value.public_send(@method_name, *@args)
      end

      # Ruby code that calls the method on the value of `value_code`, for
      # example `(source.created_at).iso8601(3)`. Literal arguments are
      # written in the code, other arguments are read from the Array that
      # `args_code` reads.
      def code(value_code, _callable_code, args_code)
        operator = @allow_nil ? "&." : "."
        arguments = @args.each_with_index.map { |arg, index| argument_code(arg, index, args_code) }

        unless SeregaResultCode::PLAIN_METHOD_NAME.match?(@method_name)
          send_arguments = [@method_name.inspect, *arguments]
          return "(#{value_code})#{operator}public_send(#{send_arguments.join(", ")})"
        end

        return "(#{value_code})#{operator}#{@method_name}" if arguments.empty?

        "(#{value_code})#{operator}#{@method_name}(#{arguments.join(", ")})"
      end

      private

      def argument_code(arg, index, args_code)
        SeregaUtils::RubyLiteral.literal?(arg) ? SeregaUtils::RubyLiteral.code(arg) : "#{args_code}[#{index}]"
      end
    end
  end
end
