# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin :explicit_many_option
    #
    # Plugin requires to add :many option when adding relationships
    # (relationships are attributes with the :serializer option or a block
    # defining a nested serializer)
    #
    # Adding this plugin makes it clearer to find if relationship returns array or single object
    #
    # @example
    #   class BaseSerializer < Serega
    #     plugin :explicit_many_option
    #   end
    #
    #   class UserSerializer < BaseSerializer
    #     attribute :name
    #   end
    #
    #   class PostSerializer < BaseSerializer
    #     attribute :text
    #     attribute :user, serializer: UserSerializer, many: false
    #     attribute :comments, serializer: PostSerializer, many: true
    #   end
    #
    module ExplicitManyOption
      # @return [Symbol] Plugin name
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
      def self.load_plugin(serializer_class, **_opts)
        require_relative "validations/check_opt_many"

        serializer_class::CheckAttributeParams.include(CheckAttributeParamsInstanceMethods)
      end

      #
      # Serega::SeregaValidations::CheckAttributeParams additional/patched class methods
      #
      # @see Serega::SeregaValidations::CheckAttributeParams
      #
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
