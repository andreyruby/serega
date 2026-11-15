# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Attribute # :nodoc:
      #
      # Attribute `:preset` option validator
      #
      class CheckOptPreset # :nodoc:
        class << self
          # Checks that the :preset option names presets of the relation
          # serializer. A serializer given as a String or a Proc, or defined
          # with a block, is checked when a plan is built.
          def call(opts, block = nil)
            return unless opts.key?(:preset)

            serializer = opts[:serializer]
            raise SeregaError, "Option :preset can be provided only together with :serializer option or a block" unless serializer || block

            check_defined(serializer, SeregaPlan::Presets.names(opts[:preset]))
          end

          private

          def check_defined(serializer, names)
            return unless serializer.is_a?(Class)

            names.each { |name| SeregaPlan::Presets.fetch_definition(serializer, name) }
          end
        end
      end
    end
  end
end
