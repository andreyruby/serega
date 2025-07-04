# frozen_string_literal: true

class Serega
  module SeregaUtils
    #
    # Utility that helps to transform preloads to array of paths
    # It is used to validate manually set `:preload_path` attribute option has one of allowed values.
    # `:preload_path` option can be used to specify where nested preloads must be attached.
    #
    # Example:
    #
    #   call({ a: { b: { c: {}, d: {} } }, e: {} })
    #
    #   => [
    #        [:a],
    #        [:a, :b],
    #        [:a, :b, :c],
    #        [:a, :b, :d],
    #        [:e]
    #      ]
    class PreloadPaths
      class << self
        #
        # Transforms user provided preloads to array of paths
        #
        # @param preloads [Array,Hash,String,Symbol,nil,false] association(s) to preload
        #
        # @return [Array] transformed preloads
        #
        def call(preloads)
          formatted_preloads = FormatUserPreloads.call(preloads)
          return FROZEN_EMPTY_ARRAY if formatted_preloads.empty?

          paths(formatted_preloads, [], [])
        end

        private

        def paths(formatted_preloads, path, result)
          formatted_preloads.each do |key, nested_preloads|
            path << key
            result << path.dup

            paths(nested_preloads, path, result)
            path.pop
          end

          result
        end
      end
    end
  end
end
