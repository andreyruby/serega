# frozen_string_literal: true

class Serega
  #
  # One generated method per attribute that is read with plain Ruby code,
  # for example `def read_full_name(source) = source.full_name`. Each method is
  # defined with the file and line of its attribute, thus a backtrace of an
  # error points to the attribute.
  #
  # `CONSTANTS` and `DEFAULTS` hold the `:const` and `:default` values of the
  # attributes, by attribute name.
  #
  # Each method name is `read_` and the attribute name with `_` in place of
  # other characters than letters, digits and `_`, for example
  # `read_first_name` for `first-name`. A name of another attribute gets a
  # number: `read_first_name_2`. Thus attribute names do not clash with
  # methods of Object, and generated code calls the methods directly.
  #
  # @private
  class SeregaAttributeValues
    # `:const` values by attribute name
    CONSTANTS = {}

    # `:default` values by attribute name
    DEFAULTS = {}

    # Method names by attribute name
    METHOD_NAMES = {}

    # Gives each subclass its own values
    def self.inherited(subclass)
      super
      subclass.const_set(:CONSTANTS, {})
      subclass.const_set(:DEFAULTS, {})
      subclass.const_set(:METHOD_NAMES, {})
    end
  end
end
