# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin :activerecord_preloads
    #
    # Automatically preloads associations to serialized objects
    #
    # Every association declared with `:preload` is loaded once during serialization using
    # ActiveRecord::Associations::Preloader, so there are no N+1 queries.
    #
    # @example
    #   class AppSerializer < Serega
    #     config.auto_preload = true
    #     plugin :activerecord_preloads
    #   end
    #
    #   class AlbumSerializer < AppSerializer
    #     # no preloads
    #     attribute :title
    #
    #     # preloads :downloads, as manually specified
    #     attribute :downloads_count, preload: :downloads, value: proc { |album| album.downloads.count }
    #   end
    #
    #   class UserSerializer < AppSerializer
    #     # no preloads
    #     attribute :username
    #
    #     # preloads :user_stats, as auto_preload is enabled for :delegate attributes
    #     attribute :comments_count, delegate: { to: :user_stats }
    #
    #     # preloads :albums, as auto_preload is enabled for :serializer attributes
    #     attribute :albums, serializer: AlbumSerializer
    #   end
    #
    #   UserSerializer.to_h(users)
    #   # 1 query to load :user_stats for all users
    #   # + 1 query to load :albums for all users
    #   # + 1 query to load :downloads for all albums
    #   # = 3 queries total, regardless of how many users/albums are serialized
    #
    module ActiverecordPreloads
      #
      # @return [Symbol] Plugin name
      #
      # @private
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
      # @private
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
      # @private
      def self.load_plugin(serializer_class, **_opts)
        require_relative "lib/preloader"
      end

      #
      # Registers the ActiveRecord preload handler
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param _opts [Hash] Plugin options
      #
      # @return [void]
      #
      # @private
      def self.after_load_plugin(serializer_class, **_opts)
        serializer_class.preload_with do |objects, preloads|
          Preloader.preload(ActiverecordPreloads.records(serializer_class, objects), preloads)
        end
      end

      #
      # The underlying records to preload onto. The :presenter plugin wraps every
      # serialized object in a SimpleDelegator, but ActiveRecord's Preloader needs
      # the real records, so unwrap them via #__getobj__ when presenter is used.
      # Objects are wrapped only when the Presenter class has custom methods.
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param objects [Array] objects serialized at the current level
      #
      # @return [Array] the underlying records
      #
      # @private
      def self.records(serializer_class, objects)
        return objects unless serializer_class.plugin_used?(:presenter)
        return objects unless serializer_class.custom_presenter?

        objects.map(&:__getobj__)
      end
    end

    register_plugin(ActiverecordPreloads.plugin_name, ActiverecordPreloads)
  end
end
