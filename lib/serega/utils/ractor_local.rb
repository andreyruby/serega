# frozen_string_literal: true

class Serega
  #
  # Utilities
  #
  # @private
  module SeregaUtils
    #
    # Values stored per Ractor, by owner and key
    #
    # @private
    class RactorLocal
      class << self
        #
        # Returns the value of the owner and key in the current Ractor,
        # stores the block result when there is none
        #
        # @param owner [Object] Owner of the value
        # @param key [Symbol] Value key
        #
        # @return [Object] Stored value
        #
        def fetch(owner, key)
          values = (store[owner] ||= {})
          values.fetch(key) { values[key] = yield }
        end

        private

        # :nocov:
        if defined?(Ractor.[])
          def store
            Ractor[:serega] ||= {}.compare_by_identity
          end
        else
          def store
            Ractor.current[:serega] ||= {}.compare_by_identity
          end
        end
        # :nocov:
      end
    end
  end
end
