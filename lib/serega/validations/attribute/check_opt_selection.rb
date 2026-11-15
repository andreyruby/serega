# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Attribute # :nodoc:
      #
      # Attribute `:only`, `:with` and `:except` options validator
      #
      class CheckOptSelection # :nodoc:
        # Field selection options of a relation
        KEYS = %i[only with except].freeze

        class << self
          # Checks that the options are given with a relation, that they name
          # attributes, and that the attributes exist in a serializer class.
          # Another serializer is checked when a plan is built.
          def call(name, opts, block = nil)
            key = KEYS.find { |option| opts.key?(option) }
            return unless key

            serializer = opts[:serializer]
            raise SeregaError, "Option #{key.inspect} can be provided only together with :serializer option or a block" unless serializer || block

            selection = KEYS.to_h { |option| [option, parse(option, opts[option])] }
            return unless serializer.is_a?(Class)

            CheckRelationSelection.check(name, serializer, selection, CheckPresetSelection)
          end

          private

          def parse(key, value)
            SeregaPlan::SelectionPlanner.parse_option(value)
          rescue SeregaError
            raise SeregaError, "Invalid option #{key.inspect} => #{value.inspect}. Must be a Symbol, a String, an Array or a Hash of attribute names"
          end
        end
      end
    end
  end
end
