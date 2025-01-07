# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module ActiverecordPreloads
      # Detects and returns found ActiveRecord objects
      class ActiveRecordObjects
        class << self
          # Iterates over provided data and selects ActiveRecord objects
          # @param data [Hash,Array,Object] any data
          # @return [Array] Found ActiveRecord objects
          def call(data)
            res = []
            extract(data, res)
            res
          end

          private

          def extract(data, res)
            case data
            when ActiveRecord::Base then res << data
            when Array then data.each { |value| extract(value, res) }
            when Hash then data.each_value { |value| extract(value, res) }
            end
          end
        end
      end
    end
  end
end
