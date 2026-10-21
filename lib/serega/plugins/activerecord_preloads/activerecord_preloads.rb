# frozen_string_literal: true

class Serega
  module SeregaPlugins
    # `plugin :activerecord_preloads` loads every `:preload` of the serialized
    # fields once, with `ActiveRecord::Associations::Preloader`
    #
    # ```ruby
    # class AppSerializer < Serega
    #   plugin :activerecord_preloads
    #   config.auto_preload = true
    # end
    # ```
    #
    # See [ActiveRecord preloads](https://github.com/andreyruby/serega/blob/master/docs/preloads.md#activerecord).
    module ActiverecordPreloads
      #
      # @return [Symbol] Plugin name
      #
      def self.plugin_name # :nodoc:
        :activerecord_preloads
      end

      # Checks requirements to load plugin
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param opts [Hash] plugin options
      #
      # @return [void]
      def self.before_load_plugin(serializer_class, **opts) # :nodoc:
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
      def self.load_plugin(serializer_class, **_opts) # :nodoc:
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
      def self.after_load_plugin(serializer_class, **_opts) # :nodoc:
        serializer_class.preload_with do |objects, preloads|
          Preloader.preload(objects, preloads)
        end
      end
    end

    register_plugin(ActiverecordPreloads.plugin_name, ActiverecordPreloads)
  end
end
