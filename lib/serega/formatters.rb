# frozen_string_literal: true

class Serega
  #
  # Formatters of attribute values. A formatter declaration is one of:
  # - a callable that gets the value, and the context when it has a second
  #   parameter or the :ctx keyword;
  # - a method name, called on the value;
  # - an Array of a method name and its arguments, for example `[:round, 2]`;
  # - a Hash with one of them as `:use` and the `:allow_nil` option.
  #
  # With `allow_nil: true` a nil value stays nil and is not formatted.
  #
  module SeregaFormatters # :nodoc:
    class << self
      # Returns the formatter of the declaration: a Callable for a callable,
      # a Method for a method name with its arguments
      def build(declaration)
        declaration = {use: declaration} unless declaration.is_a?(Hash)
        use = declaration[:use]
        allow_nil = declaration.fetch(:allow_nil, false)

        use.respond_to?(:call) ? Callable.new(use, allow_nil) : Method.new(use, allow_nil)
      end
    end
  end
end
