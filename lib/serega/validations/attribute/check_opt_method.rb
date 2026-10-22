# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    module Attribute # :nodoc:
      #
      # Attribute `:method` option validator
      #
      class CheckOptMethod # :nodoc:
        class << self
          # Checks attribute :method option
          def call(opts)
            Utils::CheckOptIsStringOrSymbol.call(opts, :method)
          end
        end
      end
    end
  end
end
