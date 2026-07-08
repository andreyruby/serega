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
    #   UserSerializer.to_h(user)
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
      end

      #
      # Registers the ActiveRecord preload handler
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param _opts [Hash] Plugin options
      #
      # @return [void]
      #
      def self.after_load_plugin(serializer_class, **_opts)
        serializer_class.preload_with { |objects, preloads| Preloader.preload(objects, preloads) }
      end
    end

    register_plugin(ActiverecordPreloads.plugin_name, ActiverecordPreloads)
  end
end
