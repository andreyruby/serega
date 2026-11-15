# frozen_string_literal: true

class Serega
  class SeregaPlan # :nodoc:
    #
    # Plans of the `only`, `with` and `except` field selection options and
    # of presets. The plans cache calls it to parse, validate and build
    # the plans of its serializer.
    #
    module SelectionPlanner # :nodoc:
      class << self
        # Parses the field selection options as provided: a String, or
        # Symbols, Arrays and Hashes of attribute names. Missing options parse
        # to empty Hashes. The selection of the requested presets is merged in. See
        # Presets.selection.
        def parse(serializer_class, only = nil, with = nil, except = nil, preset = nil)
          selection = {only: parse_option(only), with: parse_option(with), except: parse_option(except)}
          return selection if preset.nil?

          Presets.selection(serializer_class, preset, selection)
        end

        # Parses one field selection option as provided: a String, or Symbols,
        # Arrays and Hashes of attribute names. A missing option parses to an
        # empty Hash.
        def parse_option(value)
          return SeregaUtils::ParseStringSelection.parse(value) if value.is_a?(String)

          SeregaUtils::ToHash.call(value)
        end

        # Whether the parsed selection names no attributes
        def empty?(selection)
          selection[:only].empty? && selection[:with].empty? && selection[:except].empty?
        end

        # Raises AttributeNotExist for the attributes the parsed selection
        # name and the serializer does not have
        def validate(serializer_class, selection)
          SeregaValidations::CheckSelection.new.call(serializer_class, selection[:only], selection[:with], selection[:except])
        end

        # Returns the plan of the serializer with the parsed selection
        def plan(serializer_class, selection)
          SeregaPlan.new(Selection.new(serializer_class, selection))
        end
      end
    end
  end
end
