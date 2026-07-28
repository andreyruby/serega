# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin :explicit_many_option
    #
    # Requires the `:many` option on every relationship attribute (an
    # attribute with the `:serializer` option or a block defining a nested
    # serializer), so it's always explicit whether it returns one object or many.
    #
    # @example
    #   class BaseSerializer < Serega
    #     plugin :explicit_many_option
    #     config.base_serializer = self
    #   end
    #
    #   class PostSerializer < BaseSerializer
    #     attribute :text
    #
    #     attribute :user, many: false do
    #       attribute :name
    #     end
    #
    #     attribute :comments, serializer: PostSerializer, many: true
    #   end
    #
    module ExplicitManyOption
      # @return [Symbol] Plugin name
      # @private
      def self.plugin_name
        :explicit_many_option
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
        require_relative "validations/check_opt_many"

        serializer_class::CheckAttributeParams.include(CheckAttributeParamsInstanceMethods)
      end

      #
      # Serega::SeregaValidations::CheckAttributeParams additional/patched class methods
      #
      # @see Serega::SeregaValidations::CheckAttributeParams
      #
      # @private
      module CheckAttributeParamsInstanceMethods
        private

        def check_opts
          super

          CheckOptMany.call(opts, block)
        end
      end
    end

    register_plugin(ExplicitManyOption.plugin_name, ExplicitManyOption)
  end
end
