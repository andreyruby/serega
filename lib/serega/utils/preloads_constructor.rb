# frozen_string_literal: true

class Serega
  module SeregaUtils
    #
    # Finds preloads for provided attributes plan
    #
    class PreloadsConstructor
      class << self
        #
        # Constructs preloads hash for given attributes plan
        #
        # @param plan [Array<SeregaPlanPoint>] Serialization plan
        #
        # @return [Hash]
        #
        def call(plan)
          return FROZEN_EMPTY_HASH unless plan

          preloads = {}
          append_many(preloads, plan)
          preloads
        end

        private

        def append_many(preloads, plan)
          plan.points.each do |point|
            current_preloads = point.attribute.preloads
            next unless current_preloads

            child_plan = point.child_plan
            current_preloads = SeregaUtils::EnumDeepDup.call(current_preloads) if child_plan
            append_current(preloads, current_preloads)
            next unless child_plan

            each_child_preloads(preloads, point.preloads_path) do |child_preloads|
              append_many(child_preloads, child_plan)
            end
          end
        end

        def append_current(preloads, current_preloads)
          merge(preloads, current_preloads) unless current_preloads.empty?
        end

        def merge(preloads, current_preloads)
          preloads.merge!(current_preloads) do |_key, value_one, value_two|
            merge(value_one, value_two)
          end
        end

        def each_child_preloads(preloads, preloads_path)
          return yield(preloads) if preloads_path.nil?

          if preloads_path[0].is_a?(Array)
            preloads_path.each do |path|
              yield dig_fetch(preloads, path)
            end
          else
            yield dig_fetch(preloads, preloads_path)
          end
        end

        def dig_fetch(preloads, preloads_path)
          return preloads if !preloads_path || preloads_path.empty?

          preloads_path.each do |path|
            preloads = preloads.fetch(path)
          end

          preloads
        end
      end
    end
  end
end
