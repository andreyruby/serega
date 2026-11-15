# frozen_string_literal: true

class Serega
  class SeregaPlan # :nodoc:
    #
    # Presets: named field selections. The serializer calls it to define its
    # presets, and the selection planner to merge the requested presets with
    # the selection of a call.
    #
    module Presets # :nodoc:
      class << self
        # Returns the frozen definition of a new preset: the names of the
        # presets it includes and its own parsed selection. The included
        # presets are merged when a plan is built, thus a redefined preset
        # changes the presets that include it. See
        # SeregaValidations::CheckPresetParams for the checks.
        def define(serializer_class, name, preset, only, with, except)
          SeregaValidations::CheckPresetParams.new(serializer_class, name, preset, only, with, except).validate

          names = preset.nil? ? FROZEN_EMPTY_ARRAY : names(preset)
          definition = {presets: names, only: SelectionPlanner.parse_option(only), with: SelectionPlanner.parse_option(with), except: SelectionPlanner.parse_option(except)}
          deep_freeze(definition)
        end

        # Returns the selection of the requested presets, merged in order,
        # with the given parsed selection merged into it. Presets are
        # checked when they are defined, not here.
        def selection(serializer_class, preset, selection)
          merge(merged_selection(serializer_class, names(preset)), selection)
        end

        # Returns the definition of the preset, raises PresetNotExist for an
        # undefined preset
        def fetch_definition(serializer_class, name)
          serializer_class.presets.fetch(name) do
            raise PresetNotExist.new("Preset :#{name} is not defined in #{serializer_class}", serializer_class, name)
          end
        end

        private

        # Merges each option of `other` into the option of `selection` with
        # the same name. Nested Hashes merge into new Hashes, thus the frozen
        # selections of presets stay unchanged.
        def merge(selection, other)
          selection.each_key do |key|
            SeregaUtils::DeepMerge.call(selection[key], other[key])
          end
          selection
        end

        # Merges the selection of the named presets and of the presets they
        # include into `selection`, the included presets first. Presets never
        # include each other: #define checks it.
        def merged_selection(serializer_class, names, selection = {only: {}, with: {}, except: {}})
          names.each do |name|
            definition = fetch_definition(serializer_class, name)
            merged_selection(serializer_class, definition[:presets], selection)
            merge(selection, definition)
          end
          selection
        end

        def names(preset)
          case preset
          when Symbol then [preset]
          when String then [preset.to_sym]
          when Array then preset.map { |name| name_of(name, preset) }
          else raise_option_error(preset)
          end
        end

        def name_of(name, preset)
          case name
          when Symbol then name
          when String then name.to_sym
          else raise_option_error(preset)
          end
        end

        def raise_option_error(preset)
          raise SeregaError, "Invalid option :preset => #{preset.inspect}. Must be a Symbol, a String, or an Array of them"
        end

        # Freezes the nested Hashes and Arrays of a preset definition
        def deep_freeze(value)
          return value if value.frozen?

          value.each_value { |nested_value| deep_freeze(nested_value) } if value.is_a?(Hash)
          value.freeze
        end
      end
    end
  end
end
