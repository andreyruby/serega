# frozen_string_literal: true

class Serega
  module SeregaUtils # :nodoc:
    #
    # Merges nested hashes
    #
    class DeepMerge # :nodoc:
      class << self
        # Merges `other` into `hash` in place. Nested hashes merge into new
        # hashes, thus `other` stays unchanged. Other values of `other` win.
        def call(hash, other)
          hash.merge!(other) { |_key, this_val, other_val| merge_values(this_val, other_val) }
        end

        private

        def merge_values(this_val, other_val)
          return other_val unless this_val.is_a?(Hash) && other_val.is_a?(Hash)

          this_val.merge(other_val) { |_key, this_nested, other_nested| merge_values(this_nested, other_nested) }
        end
      end
    end
  end
end
