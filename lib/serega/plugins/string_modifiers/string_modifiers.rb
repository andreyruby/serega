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
        serializer_class.include(InstanceMethods)
        require_relative "parse_string_modifiers"
      end

      #
      # Serega additional/patched instance methods
      #
      # @see Serega
      #
      # @private
      module InstanceMethods
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
