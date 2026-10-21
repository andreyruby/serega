# frozen_string_literal: true

class Serega
  #
  # Validations
  #
  module SeregaValidations # :nodoc:
    #
    # Validations for attribute params
    #
    class CheckAttributeParams # :nodoc:
      #
      # Validations for attribute params instance methods
      #
      module InstanceMethods # :nodoc:
        # @return [Symbol] validated attribute name
        attr_reader :name

        # @return [Hash] validated attribute options
        attr_reader :opts

        # @return [nil, Proc] validated attribute block
        attr_reader :block

        #
        # Initializes attribute params validator
        #
        # @param serializer_class [Class<Serega>] serializer of the attribute
        # @param name [Symbol] attribute name
        # @param opts [Hash] attribute options
        # @param block [nil, Proc] block provided to attribute
        #
        # @return [void]
        #
        def initialize(serializer_class, name, opts, block)
          @serializer_class = serializer_class
          @name = name
          @opts = opts
          @block = block
        end

        #
        # Validates attribute params
        #
        def validate
          check_name if check_attribute_name
          check_opts
          check_block
        end

        private

        def check_name
          Attribute::CheckName.call(name)
        end

        def check_opts
          Utils::CheckAllowedKeys.call(opts, allowed_opts_keys, :attribute)

          Attribute::CheckOptBaseSerializer.call(opts, block)
          Attribute::CheckOptConst.call(opts)
          Attribute::CheckOptDelegate.call(opts)
          Attribute::CheckOptFormat.call(opts, @serializer_class)
          Attribute::CheckOptHashAccess.call(opts)
          Attribute::CheckOptHide.call(opts)
          Attribute::CheckOptIf.call(opts)
          Attribute::CheckOptIfValue.call(opts)
          Attribute::CheckOptMethod.call(opts)
          Attribute::CheckOptMany.call(opts, block, require_many)
          Attribute::CheckOptPreload.call(opts)
          Attribute::CheckOptSerializer.call(opts, block)
          Attribute::CheckOptUnless.call(opts)
          Attribute::CheckOptUnlessValue.call(opts)
          Attribute::CheckOptValue.call(opts)
          Attribute::CheckOptBatch.call(@serializer_class, name, opts)
        end

        def check_block
          Attribute::CheckBlock.call(block)
        end

        def allowed_opts_keys
          @serializer_class.config.attribute_keys
        end

        def check_attribute_name
          @serializer_class.config.check_attribute_name
        end

        def require_many
          @serializer_class.config.require_many
        end
      end

      include InstanceMethods
    end
  end
end
