# frozen_string_literal: true

class Serega
  #
  # Utilities
  #
  module SeregaUtils # :nodoc:
    #
    # Values stored in the current Ractor by key
    #
    class RactorLocal # :nodoc:
      class << self
        # Returns the key of the owner value with the name
        def key(owner, name)
          :"serega_#{name}_#{owner.object_id}"
        end

        # :nocov:
        if defined?(Ractor.[])
          # Returns the value of the key in the current Ractor, stores the
          # block result when there is none
          def fetch(key)
            Ractor[key] ||= yield
          end
        else
          # Returns the value of the key in the current Ractor, stores the
          # block result when there is none
          def fetch(key)
            Ractor.current[key] ||= yield
          end
        end
        # :nocov:
      end
    end
  end
end
