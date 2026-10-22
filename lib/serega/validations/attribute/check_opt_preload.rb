# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Attribute # :nodoc:
      #
      # Validator for attribute :preload option
      #
      class CheckOptPreload # :nodoc:
        class << self
          # Checks :preload option
          def call(opts)
            raise SeregaError, "Option :preload value can not be `true`" if opts[:preload] == true
          end
        end
      end
    end
  end
end
