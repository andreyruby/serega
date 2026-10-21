# frozen_string_literal: true

class Serega
  module SeregaPlugins
    # `plugin :explicit_many_option` requires the `:many` option on every
    # relation, an attribute with `:serializer` or a block
    #
    # ```ruby
    # plugin :explicit_many_option
    #
    # attribute :comments, serializer: CommentSerializer, many: true
    # ```
    #
    # See [:many](https://github.com/andreyruby/serega/blob/master/docs/attributes.md#many).
    module ExplicitManyOption
      # @return [Symbol] Plugin name
      def self.plugin_name # :nodoc:
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
      def self.load_plugin(serializer_class, **_opts) # :nodoc:
        require_relative "validations/check_opt_many"

        serializer_class::CheckAttributeParams.include(CheckAttributeParamsInstanceMethods)
      end

      #
      # Serega::SeregaValidations::CheckAttributeParams additional/patched class methods
      #
      # @see Serega::SeregaValidations::CheckAttributeParams
      #
      module CheckAttributeParamsInstanceMethods # :nodoc:
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
