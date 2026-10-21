# frozen_string_literal: true

class Serega
  module SeregaPlugins
    # Plugin `:string_modifiers`: accepts `only:`, `except:` and `with:` as
    # one String, with nested fields in parentheses
    #
    # ```ruby
    # plugin :string_modifiers
    #
    # UserSerializer.to_h(user, only: "username,friends(first_name)")
    # ```
    #
    # See [Plugin :string_modifiers](https://github.com/andreyruby/serega/blob/master/docs/plugins.md#plugin-string_modifiers).
    module StringModifiers
      # @return [Symbol] Plugin name
      def self.plugin_name # :nodoc:
        :string_modifiers
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
        require_relative "parse_string_modifiers"
        serializer_class.extend(ClassMethods)
        serializer_class.instance_variable_set(:@plan_cache, PlanCache.new(serializer_class))
      end

      #
      # Serega additional/patched class methods
      #
      # @see Serega
      #
      module ClassMethods # :nodoc:
        # @return [Class<PlanCache>] Plans cache that parses string modifiers
        def plan_cache_class
          PlanCache
        end
      end

      #
      # Plans cache that parses string modifiers
      #
      # @see Serega::SeregaPlan::Cache
      #
      class PlanCache < SeregaPlan::Cache # :nodoc:
        private

        def parse_modifier(value)
          return ParseStringModifiers.parse(value) if value.is_a?(String)

          super
        end
      end
    end

    register_plugin(StringModifiers.plugin_name, StringModifiers)
  end
end
