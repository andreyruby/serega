# frozen_string_literal: true

class Serega
  class SeregaPlan # :nodoc:
    #
    # Presets of saved `only`, `with` and `except` modifiers. The serializer
    # calls it to define its presets, and the modifiers planner to merge the
    # requested presets with the modifiers of a call.
    #
    module Presets # :nodoc:
      class << self
        # Returns the frozen definition of a new preset: the names of the
        # presets it includes and its own parsed modifiers. The included
        # presets are merged when a plan is built, thus a redefined preset
        # changes the presets that include it. See
        # SeregaValidations::CheckPresetParams for the checks.
        def define(serializer_class, name, preset, only, with, except)
          SeregaValidations::CheckPresetParams.new(serializer_class, name, preset, only, with, except).validate

          names = preset.nil? ? FROZEN_EMPTY_ARRAY : names(preset)
          definition = {presets: names, only: ModifiersPlanner.parse_modifier(only), with: ModifiersPlanner.parse_modifier(with), except: ModifiersPlanner.parse_modifier(except)}
          deep_freeze(definition)
        end

        # Returns the modifiers of the requested presets, merged in order,
        # with the given parsed modifiers merged into them. Presets are
        # checked when they are defined, not here.
        def modifiers(serializer_class, preset, modifiers)
          merge(merged_modifiers(serializer_class, names(preset)), modifiers)
        end

        # Returns the definition of the preset, raises PresetNotExist for an
        # undefined preset
        def fetch_definition(serializer_class, name)
          serializer_class.presets.fetch(name) do
            raise PresetNotExist.new("Preset :#{name} is not defined in #{serializer_class}", serializer_class, name)
          end
        end

        private

        # Merges each modifier of `other` into the modifier of `modifiers`
        # with the same name. Nested Hashes merge into new Hashes, thus the
        # frozen modifiers of presets stay unchanged.
        def merge(modifiers, other)
          modifiers.each_key do |key|
            SeregaUtils::DeepMerge.call(modifiers[key], other[key])
          end
          modifiers
        end

        # Merges the modifiers of the named presets and of the presets they
        # include into `modifiers`, the included presets first. Presets never
        # include each other: #define checks it.
        def merged_modifiers(serializer_class, names, modifiers = {only: {}, with: {}, except: {}})
          names.each do |name|
            definition = fetch_definition(serializer_class, name)
            merged_modifiers(serializer_class, definition[:presets], modifiers)
            merge(modifiers, definition)
          end
          modifiers
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
