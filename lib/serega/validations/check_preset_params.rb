# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    #
    # Validations of the parameters of `Serega.preset`. Nested fields of a
    # relation with a serializer name or a Proc are not checked: that
    # serializer may be defined later.
    #
    class CheckPresetParams # :nodoc:
      # Initializes the preset params validator
      def initialize(serializer_class, name, preset, only, with, except)
        @serializer_class = serializer_class
        @name = name
        @preset = preset
        @only = only
        @with = with
        @except = except
      end

      # Raises an error for an invalid name, an invalid `:preset` option,
      # presets that include each other, invalid field selection options and
      # a preset without a field selection, PresetNotExist for an undefined
      # included preset, and AttributeNotExist for unknown attributes
      def validate
        check_name
        names = included_names
        check_included_presets(names)
        check_selection(names)
      end

      private

      def check_name
        return if @name.is_a?(Symbol) || @name.is_a?(String)

        raise SeregaError, "Preset name must be a Symbol or a String, #{@name.inspect} provided"
      end

      def included_names
        return FROZEN_EMPTY_ARRAY if @preset.nil?

        names = @preset.is_a?(Array) ? @preset : [@preset]
        check_preset_option(names)
        names.map(&:to_sym)
      end

      def check_preset_option(names)
        return if names.all? { |name| name.is_a?(Symbol) || name.is_a?(String) }

        raise SeregaError, "Invalid option :preset => #{@preset.inspect}. Must be a Symbol, a String, or an Array of them"
      end

      def check_included_presets(names)
        check_defined(names)
        check_cycle(names, [@name.to_sym])
      end

      def check_defined(names)
        names.each { |included_name| SeregaPlan::Presets.fetch_definition(@serializer_class, included_name) }
      end

      # Raises an error when the included presets, or the presets they
      # include, include the new preset. `path` lists the presets from the
      # new one, its first item, to the included ones. `visited` keeps the
      # presets already walked, so each preset is walked once.
      def check_cycle(names, path, visited = Set.new)
        names.each do |included_name|
          included_path = [*path, included_name]
          raise SeregaError, "Presets of #{@serializer_class} include each other: #{included_path.join(" -> ")}" if included_name == path.first
          next unless visited.add?(included_name)

          check_cycle(@serializer_class.presets[included_name][:presets], included_path, visited)
        end
      end

      def parse_option(key, value)
        SeregaPlan::SelectionPlanner.parse_option(value)
      rescue SeregaError
        raise SeregaError, "Invalid :#{key} => #{value.inspect} in preset :#{@name}. Must be a Symbol, a String, an Array or a Hash of attribute names"
      end

      def check_selection(names)
        selection = {only: parse_option(:only, @only), with: parse_option(:with, @with), except: parse_option(:except, @except)}
        check_not_empty(names, selection)
        check_attributes(selection)
      end

      def check_attributes(selection)
        CheckPresetSelection.new.call(@serializer_class, selection[:only], selection[:with], selection[:except])
      rescue AttributeNotExist => error
        attributes = error.attributes
        raise AttributeNotExist.new("Preset :#{@name} names not existing attributes: #{attributes.join(", ")}", error.serializer, attributes)
      end

      def check_not_empty(names, selection)
        return unless names.empty? && SeregaPlan::SelectionPlanner.empty?(selection)

        raise SeregaError, "Preset :#{@name} must select fields with :only, :with, :except or :preset"
      end
    end
  end
end
