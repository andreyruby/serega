# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Initiate # :nodoc:
      #
      # Modifiers validation of a preset definition. It skips the nested
      # fields of relations with a serializer name or a Proc, as that
      # serializer may be defined later.
      #
      class CheckPresetModifiers < CheckModifiers # :nodoc:
        private

        def validate_nested(name, attribute, nested_fields)
          serializer = attribute.initials[:opts][:serializer]
          return if serializer.is_a?(String) || serializer.is_a?(Proc)

          super
        end
      end
    end
  end
end
