# frozen_string_literal: true

class Serega
  #
  # Attribute value resolvers
  #
  module AttributeValueResolvers # :nodoc:
    #
    # Parent class of the value resolvers that Serega builds from the
    # attribute options. A `:value` callable of the user is no resolver, thus
    # SeregaAttribute asks only resolvers for their code.
    #
    class Base # :nodoc:
      # Ruby code that reads the value of the source, nil when the value
      # has no code
      def code(_source_variable)
      end

      # Method of the object that gives the value, nil when no method of
      # the object gives it
      def object_method
      end

      # Whether the value is the `:const` option
      def const?
        false
      end
    end
  end
end
