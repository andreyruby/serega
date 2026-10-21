# frozen_string_literal: true

class Serega
  # Built-in features, turned on with Serega::ClassMethods#plugin.
  #
  # See [Guides](https://github.com/andreyruby/serega/blob/master/docs/README.md).
  module SeregaPlugins
    @plugins = {}

    class << self
      # Registers given plugin to be able to load it using symbol name.
      #
      #   SeregaPlugins.register_plugin(:plugin_name, PluginModule)
      def register_plugin(name, mod) # :nodoc:
        @plugins[name] = mod
      end

      # Loads plugin code and returns plugin core module. Raises SeregaError
      # when the plugin does not exist.
      #
      #   SeregaPlugins.find_plugin(:root) # => SeregaPlugins::Root
      #   SeregaPlugins.find_plugin(Root) # => Root
      def find_plugin(name) # :nodoc:
        return name if name.is_a?(Module)
        return @plugins[name] if @plugins.key?(name)

        require_plugin(name)

        @plugins[name] || raise(SeregaError, "Plugin '#{name}' did not register itself correctly")
      end

      private

      def require_plugin(name)
        require "serega/plugins/#{name}/#{name}"
      rescue LoadError
        raise SeregaError, "Plugin '#{name}' does not exist"
      end
    end
  end
end
