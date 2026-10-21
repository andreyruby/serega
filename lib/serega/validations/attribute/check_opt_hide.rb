# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Attribute # :nodoc:
      #
      # Attribute `:hide` option validator
      #
      class CheckOptHide # :nodoc:
        # Checks attribute :hide option
        def self.call(opts)
          Utils::CheckOptIsBool.call(opts, :hide)
        end
      end
    end
  end
end
