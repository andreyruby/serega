# frozen_string_literal: true

class Serega
  #
  # Utilities
  #
  # @private
  module SeregaUtils
    #
    # Values stored in the current Ractor by key
    #
    # @private
    class RactorLocal
      class << self
        #
        # Returns the key of the owner value with the name
        #
        # @param owner [Object] Owner of the value
        # @param name [Symbol] Value name
        #
        # @return [Symbol] Key of the value
        #
        def key(owner, name)
          :"serega_#{name}_#{owner.object_id}"
        end

        # :nocov:
        if defined?(Ractor.[])
          #
          # Returns the value of the key in the current Ractor, stores the
          # block result when there is none
          #
          # @param key [Symbol] Value key
          #
          # @return [Object] Stored value
          #
          def fetch(key)
            Ractor[key] ||= yield
          end
        else
          #
          # Returns the value of the key in the current Ractor, stores the
          # block result when there is none
          #
          # @param key [Symbol] Value key
          #
          # @return [Object] Stored value
          #
          def fetch(key)
            Ractor.current[key] ||= yield
          end
        end
        # :nocov:
      end
    end
  end
end
