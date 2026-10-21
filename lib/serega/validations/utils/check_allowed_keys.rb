# frozen_string_literal: true

class Serega
  module SeregaValidations # :nodoc:
    #
    # Validations Utilities
    #
    module Utils # :nodoc:
      #
      # Utility to check all hash keys are allowed
      #
      class CheckAllowedKeys # :nodoc:
        # Checks hash keys are allowed
        def self.call(opts, allowed_keys, parameter_name)
          opts.each_key do |key|
            next if allowed_keys.include?(key)

            raise SeregaError,
              "Invalid #{parameter_name} option #{key.inspect}." \
              " Allowed options are: #{allowed_keys.map(&:inspect).sort.join(", ")}"
          end
        end
      end
    end
  end
end
