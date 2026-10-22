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

    class << self
      # Loads the code of the plugin and returns its module. Raises
      # SeregaError when the plugin does not exist.
      def find(name) # :nodoc:
        module_name = MODULES.fetch(name) { raise SeregaError, "Plugin #{name.inspect} does not exist" }
        require_relative "plugins/#{name}/#{name}"
        const_get(module_name)
      end
    end
  end
end
