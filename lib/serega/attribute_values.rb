# frozen_string_literal: true

class Serega
  #
  # Values of the attributes that generated code reads, by attribute name:
  # `CONSTANTS` and `DEFAULTS` hold the `:const` and `:default` values,
  # `FORMATTERS` the formatter callables and `FORMATTER_ARGS` the arguments
  # of method formatters.
  #
  class SeregaAttributeValues # :nodoc:
    # `:const` values by attribute name
    CONSTANTS = {}

    # `:default` values by attribute name
    DEFAULTS = {}

    # Formatter callables by attribute name
    FORMATTERS = {}

    # Arguments of method formatters by attribute name
    FORMATTER_ARGS = {}

    # Gives each subclass its own values
    def self.inherited(subclass)
      super
      subclass.const_set(:CONSTANTS, {})
      subclass.const_set(:DEFAULTS, {})
      subclass.const_set(:FORMATTERS, {})
      subclass.const_set(:FORMATTER_ARGS, {})
    end
  end
end
