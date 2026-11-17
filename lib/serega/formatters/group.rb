# frozen_string_literal: true

class Serega
  module SeregaFormatters # :nodoc:
    #
    # Adds formatters to a serializer, `f` in a `formatters do |f|` block
    #
    # ```ruby
    # formatters do |f|
    #   f.add :iso8601, [:iso8601, 3], allow_nil: true
    # end
    # ```
    #
    # See [Formatters](https://github.com/andreyruby/serega/blob/master/docs/formatters.md).
    #
    class Group
      def initialize(serializer_class) # :nodoc:
        @serializer_class = serializer_class
      end

      #
      # Defines a named formatter, with the arguments of `formatter`
      #
      # ```ruby
      # f.add :iso8601, [:iso8601, 3], allow_nil: true
      # f.add(:money) { |cents, ctx| "#{cents / 100.0} #{ctx[:currency]}" }
      # ```
      #
      def add(name, value = nil, allow_nil: false, &block)
        @serializer_class.formatter(name, value, allow_nil: allow_nil, &block)
        nil
      end
    end
  end
end
