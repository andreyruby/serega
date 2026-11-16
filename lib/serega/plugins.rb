# frozen_string_literal: true

class Serega
  # Built-in features, turned on with Serega::ClassMethods#plugin.
  #
  # See [Guides](https://github.com/andreyruby/serega/blob/master/docs/README.md).
  module SeregaPlugins
    # Plugin module names, by plugin name
    MODULES = { # :nodoc:
      root: :Root,
      metadata: :Metadata,
      context_metadata: :ContextMetadata,
      activerecord_preloads: :ActiverecordPreloads
    }.freeze

    # Names of deprecated plugins, replaced by response serializers
    DEPRECATED = %i[root metadata context_metadata].freeze # :nodoc:

    class << self
      # Loads the code of the plugin and returns its module. Raises
      # SeregaError when the plugin does not exist.
      def find(name) # :nodoc:
        module_name = MODULES.fetch(name) { raise SeregaError, "Plugin #{name.inspect} does not exist" }
        require_relative "plugins/#{name}/#{name}"
        const_get(module_name)
      end

      # Warning text for a deprecated plugin, `nil` for the others
      def deprecation_warning(serializer_class, name) # :nodoc:
        return unless DEPRECATED.include?(name)

        "#{serializer_class}: plugin #{name.inspect} is deprecated. Migrate to a response serializer with data and " \
          "meta attributes: " \
          "https://github.com/andreyruby/serega/blob/master/docs/migrating-from-root-and-metadata.md. " \
          "Set config.deprecation_warnings = false to hide this warning."
      end
    end
  end
end
