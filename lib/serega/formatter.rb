# frozen_string_literal: true

class Serega
  #
  # Formats attribute values. A formatter is one of:
  # - a callable that gets the value, and the context when it has a second
  #   parameter or the :ctx keyword;
  # - a method name, called on the value;
  # - an Array of a method name and its arguments, for example `[:round, 2]`;
  # - a Hash with one of them as `:use` and the `:allow_nil` option.
  #
  # With `allow_nil: true` a nil value stays nil and is not formatted.
  #
  # @private
  class SeregaFormatter
    # @return [#call, nil] Callable that formats a value, nil for a method formatter
    attr_reader :callable

    # @return [Array, nil] Arguments of the method, nil for a callable formatter
    attr_reader :args

    #
    # @param formatter [#call, Symbol, Array, Hash] Formatter
    #
    def initialize(formatter)
      formatter = {use: formatter} unless formatter.is_a?(Hash)
      use = formatter[:use]
      @allow_nil = formatter.fetch(:allow_nil, false)

      if use.respond_to?(:call)
        @method_name = nil
        @args = nil
        @callable = use
        @signature = SeregaUtils::MethodSignature.call(use, pos_limit: 2, keyword_args: [:ctx])
      else
        method_name, *args = use
        @method_name = method_name
        @args = args
        @callable = nil
        @signature = nil
      end
    end

    #
    # Formats the value
    #
    # @param value [Object] Value to format
    # @param context [Hash] Serialization context
    #
    # @return [Object] Formatted value
    #
    def call(value, context)
      return if value.nil? && @allow_nil
      return value.public_send(@method_name, *@args) if @method_name

      case @signature
      when "1" then @callable.call(value)
      when "1_ctx" then @callable.call(value, ctx: context)
      else @callable.call(value, context) # "2"
      end
    end

    #
    # Ruby code that formats the value of `value_code`. A method is called
    # directly, for example `(source.created_at).iso8601(3)`. Literal
    # arguments are written in the code, other arguments are read from the
    # Array that `args_code` reads. A callable is read with `callable_code`.
    #
    # @param value_code [String] Code of the value to format
    # @param callable_code [String] Code of the callable
    # @param args_code [String] Code of the method arguments
    #
    # @return [String, nil] Code, or nil when the formatter needs the context
    #
    def code(value_code, callable_code, args_code)
      return method_call_code(value_code, args_code) if @method_name
      return unless @signature == "1"
      return "#{callable_code}.call(#{value_code})" unless @allow_nil

      "(value = #{value_code}).nil? ? nil : #{callable_code}.call(value)"
    end

    private

    def method_call_code(value_code, args_code)
      operator = @allow_nil ? "&." : "."
      arguments = @args.each_with_index.map { |arg, index| argument_code(arg, index, args_code) }

      unless SeregaResultCode::PLAIN_METHOD_NAME.match?(@method_name)
        send_arguments = [@method_name.inspect, *arguments]
        return "(#{value_code})#{operator}public_send(#{send_arguments.join(", ")})"
      end

      return "(#{value_code})#{operator}#{@method_name}" if arguments.empty?

      "(#{value_code})#{operator}#{@method_name}(#{arguments.join(", ")})"
    end

    # Literal arguments are written in the code, other arguments are read
    # from the Array of arguments
    def argument_code(arg, index, args_code)
      literal?(arg) ? literal_code(arg) : "#{args_code}[#{index}]"
    end

    def literal?(arg)
      case arg
      when Integer, Symbol, String, true, false, nil then true
      when Float then arg.finite?
      else false
      end
    end

    def literal_code(arg)
      arg.is_a?(String) ? "#{arg.inspect}.freeze" : arg.inspect
    end
  end
end
