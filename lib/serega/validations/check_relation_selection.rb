# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    #
    # Checks the attributes that the `only`, `with` and `except` options of
    # a relation name
    #
    class CheckRelationSelection # :nodoc:
      class << self
        # Checks the options of a relation when its plan is built, for a
        # serializer given as a String or a Proc, or defined with a block. A
        # serializer class is checked when the attribute is defined.
        def call(attribute, serializer)
          return if attribute.initials[:opts][:serializer].is_a?(Class)

          check(attribute.name, serializer, attribute.selection, CheckSelection)
        end

        # Raises AttributeNotExist that names the relation for attributes
        # the selection names and the serializer does not have
        def check(name, serializer, selection, validator)
          validator.new.call(serializer, selection[:only], selection[:with], selection[:except])
        rescue AttributeNotExist => error
          attributes = error.attributes
          raise AttributeNotExist.new("Relation :#{name} names not existing attributes: #{attributes.join(", ")}", error.serializer, attributes)
        end
      end
    end
  end
end
