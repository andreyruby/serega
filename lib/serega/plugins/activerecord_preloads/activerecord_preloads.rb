# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin :activerecord_preloads
    #
    # Automatically preloads associations to serialized objects
    #
    # It takes all defined preloads from serialized attributes (including attributes from serialized relations),
    # merges them into single associations hash and then uses ActiveRecord::Associations::Preloader
    # to preload all associations.
    #
    # @example
    #   class AppSerializer < Serega
    #     config.auto_preload_attributes_with_delegate = true
    #     config.auto_preload_attributes_with_serializer = true
    #     config.hide_by_default = [:preload]
    #
    #     plugin :activerecord_preloads
    #   end
    #
    #   class UserSerializer < AppSerializer
    #     # no preloads
    #     attribute :username
    #
    #     # preloads `:user_stats` as auto_preload_attributes_with_delegate option is true
    #     attribute :comments_count, delegate: { to: :user_stats }
    #
    #     # preloads `:albums` as auto_preload_attributes_with_serializer option is true
    #     attribute :albums, serializer: AlbumSerializer, hide: false
    #   end
    #
    #   class AlbumSerializer < AppSerializer
    #     # no preloads
    #     attribute :title
    #
    #     # preloads :downloads_count as manually specified
    #     attribute :downloads_count, preload: :downloads, value: proc { |album| album.downloads.count }
    #   end
    #
    #   UserSerializer.to_h(user) # => preloads {users_stats: {}, albums: { downloads: {} }}
    #
    module ActiverecordPreloads
      #
      # @return [Symbol] Plugin name
      #
      def self.plugin_name
        :activerecord_preloads
      end

      # Checks requirements to load plugin
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param opts [Hash] plugin options
      #
      # @return [void]
      #
      def self.before_load_plugin(serializer_class, **opts)
        opts.each_key do |key|
          raise SeregaError, "Plugin #{plugin_name.inspect} does not accept the #{key.inspect} option. No options are allowed"
        end
      end

      #
      # Applies plugin code to specific serializer
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param _opts [Hash] Plugin options
      #
      # @return [void]
      #
      def self.load_plugin(serializer_class, **_opts)
        require_relative "lib/preloader"
        require_relative "lib/active_record_objects"

        serializer_class.include(InstanceMethods)
        serializer_class::SeregaBatchAttributeLoader.include(BatchAttributeLoaderInstanceMethods)
      end

      #
      # Overrides SeregaBatch::AttributeLoader class instance methods
      #
      module BatchAttributeLoaderInstanceMethods
        private

        # Preloads associations to batch-generated data
        def load_one(serializer_class, batch_loader_name, context)
          batch_loaded_data = super

          preloads = point.preloads
          return batch_loaded_data if preloads.empty?

          ar_objects = ActiveRecordObjects.call(batch_loaded_data)
          Preloader.preload(ar_objects, preloads)

          batch_loaded_data
        end
      end

      #
      # Overrides Serega class instance methods
      #
      module InstanceMethods
        #
        # Preloads associations to object
        #
        # @param object [Object] Any object
        # @return provided object
        #
        def preload_associations_to(object)
          return object if object.nil? || (object.is_a?(Array) && object.empty?)

          preloads = preloads() # `preloads()` method comes from :preloads plugin
          return object if preloads.empty?

          Preloader.preload(object, preloads)
          object
        end

        private

        #
        # Override original #serialize method
        # Preloads associations to object before serialization
        #
        def serialize(object, _opts)
          preload_associations_to(object)
          super
        end
      end
    end

    register_plugin(ActiverecordPreloads.plugin_name, ActiverecordPreloads)
  end
end
