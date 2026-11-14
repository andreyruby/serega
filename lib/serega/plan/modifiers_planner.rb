# frozen_string_literal: true

class Serega
  class SeregaPlan # :nodoc:
    #
    # Plans of the `only`, `with` and `except` modifiers and the presets of
    # saved modifiers. The plans cache calls it to parse, validate and build
    # the plans of its serializer.
    #
    module ModifiersPlanner # :nodoc:
      class << self
        # Parses the modifiers as provided: a String, or Symbols, Arrays and
        # Hashes of attribute names. Missing modifiers parse to empty Hashes.
        # The modifiers of the requested presets are merged in. See
        # Presets.modifiers.
        def parse(serializer_class, only = nil, with = nil, except = nil, preset = nil)
          modifiers = {only: parse_modifier(only), with: parse_modifier(with), except: parse_modifier(except)}
          return modifiers if preset.nil?

          Presets.modifiers(serializer_class, preset, modifiers)
        end

        # Parses one modifier as provided: a String, or Symbols, Arrays and
        # Hashes of attribute names. A missing modifier parses to an empty
        # Hash.
        def parse_modifier(value)
          return SeregaUtils::ParseStringModifiers.parse(value) if value.is_a?(String)

          SeregaUtils::ToHash.call(value)
        end

        # Whether the parsed modifiers name no attributes
        def empty?(modifiers)
          modifiers[:only].empty? && modifiers[:with].empty? && modifiers[:except].empty?
        end

        # Raises AttributeNotExist for the attributes the parsed modifiers
        # name and the serializer does not have
        def validate(serializer_class, modifiers)
          SeregaValidations::Initiate::CheckModifiers.new.call(serializer_class, modifiers[:only], modifiers[:with], modifiers[:except])
        end

        # Returns the plan of the serializer with the parsed modifiers
        def plan(serializer_class, modifiers)
          SeregaPlan.new(Selection.new(serializer_class, modifiers))
        end
      end
    end
  end
end
