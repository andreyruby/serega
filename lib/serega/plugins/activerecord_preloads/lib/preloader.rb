# frozen_string_literal: true

class Serega
  module SeregaPlugins
    module ActiverecordPreloads
      # Handles preloads for different types of initial records
      class Preloader # :nodoc:
        class << self
          # Preloads associations to records
          def preload(object, preloads)
            return object if object.nil? || (object.is_a?(Array) && object.empty?)

            preload_handler = handlers.find { |handler| handler.fit?(object) }
            raise SeregaError, "Can't preload #{preloads.inspect} to #{object.inspect}" unless preload_handler

            preload_handler.preload(object, preloads)
          end

          # Returns handlers which will try to check if the object to serialize fits for preloading using this handler
          def handlers
            @handlers ||= [
              ActiverecordRelation,
              ActiverecordObject,
              ActiverecordArray,
              ActiverecordEnumerator
            ].freeze
          end
        end
      end

      # Associations loader for prepared records
      class Loader # :nodoc:
        # :nocov: We can check only one version of activerecord

        # Preloads associations to records
        def self.call(records, associations)
          if ActiveRecord::VERSION::MAJOR >= 7
            ActiveRecord::Associations::Preloader.new(records: records, associations: associations).call
          else
            ActiveRecord::Associations::Preloader.new.preload(records, associations)
          end
        end
        # :nocov:
      end

      # Preloader adapter for ActiveRecord object
      class ActiverecordObject # :nodoc:
        class << self
          # Checks object is kind of ActiveRecord::Base
          def fit?(object)
            object.is_a?(ActiveRecord::Base)
          end

          # Preloads associations to ActiveRecord::Base record
          def preload(record, preloads)
            Loader.call([record], preloads)
            record
          end
        end
      end

      # Preloader adapter for ActiveRecord::Relation
      class ActiverecordRelation # :nodoc:
        class << self
          # Checks object is kind of ActiveRecord::Relation
          def fit?(object)
            object.is_a?(ActiveRecord::Relation)
          end

          # Preloads associations to ActiveRecord::Relation
          def preload(scope, preloads)
            scope.load
            Loader.call(scope.to_a, preloads)
            scope
          end
        end
      end

      # Preloader adapter for Array of ActiveRecord objects
      class ActiverecordArray # :nodoc:
        class << self
          # Checks object is an array of ActiveRecord::Base objects
          def fit?(object)
            object.is_a?(Array) &&
              ActiverecordObject.fit?(object.first) &&
              same_kind?(object)
          end

          # Preloads associations to array with ActiveRecord::Base objects
          def preload(records, preloads)
            Loader.call(records, preloads)
            records
          end

          private

          def same_kind?(records)
            first_object_class = records.first.class
            records.all? { |record| record.instance_of?(first_object_class) }
          end
        end
      end

      # Preloader adapter for Enumerator with ActiveRecord objects
      class ActiverecordEnumerator # :nodoc:
        class << self
          # Checks object is an Enumerator with each value is a ActiveRecord::Base object
          def fit?(object)
            object.is_a?(Enumerator) &&
              ActiverecordArray.fit?(object.to_a)
          end

          # Preloads associations to Enumerator with ActiveRecord::Base objects
          def preload(enum, preloads)
            ActiverecordArray.preload(enum.to_a, preloads)
            enum
          end
        end
      end
    end
  end
end
