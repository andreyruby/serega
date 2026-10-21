# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin :string_modifiers
    #
    # Allows `:only`, `:except` and `:with` to be given as a single comma-separated
    # string, with nested attributes in parentheses. Useful for accepting a field
    # list straight from a query parameter.
    #
    # @example
    #   class UserSerializer < Serega
    #     plugin :string_modifiers
    #
    #     attribute :username
    #     attribute :first_name
    #     attribute :addresses, serializer: AddressSerializer, hide: true
    #   end
    #
    #   UserSerializer.to_h(user, only: "username,addresses(line1,line2)")
    #
    module StringModifiers
      # @return [Symbol] Plugin name
      # @private
      def self.plugin_name
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
      # @private
      def self.load_plugin(serializer_class, **_opts)
        require_relative "parse_string_modifiers"
        serializer_class.extend(ClassMethods)
        serializer_class.instance_variable_set(:@plan_cache, PlanCache.new(serializer_class))
      end

      #
      # Serega additional/patched class methods
      #
      # @see Serega
      #
      # @private
      module ClassMethods
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
      # @private
      class PlanCache < SeregaPlan::Cache
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
