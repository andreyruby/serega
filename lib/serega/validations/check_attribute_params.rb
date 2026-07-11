# frozen_string_literal: true

class Serega
  #
  # Validations
  #
  module SeregaValidations
    #
    # Validations for attribute params
    #
    class CheckAttributeParams
      #
      # Validations for attribute params instance methods
      #
      module InstanceMethods
        # @return [Symbol] validated attribute name
        attr_reader :name

        # @return [Hash] validated attribute options
        attr_reader :opts

        # @return [nil, Proc] validated attribute block
        attr_reader :block

        #
        # Initializes attribute params validator
        #
        # @param name [Symbol] attribute name
        # @param opts [Hash] attribute options
        # @param block [nil, Proc] block provided to attribute
        #
        # @return [void]
        #
        def initialize(name, opts, block)
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

        # Patched in:
        # - plugin :context_metadata (checks context metadata option which is :meta by default)
        # - plugin :formatters (checks :format option)
        # - plugin :if (checks :if, :if_value, :unless, :unless_value options)
        def check_opts
          Utils::CheckAllowedKeys.call(opts, allowed_opts_keys, :attribute)

          Attribute::CheckOptBaseSerializer.call(opts, block)
          Attribute::CheckOptConst.call(opts)
          Attribute::CheckOptDelegate.call(opts)
          Attribute::CheckOptHashAccess.call(opts)
          Attribute::CheckOptHide.call(opts)
          Attribute::CheckOptMethod.call(opts)
          Attribute::CheckOptMany.call(opts, block)
          Attribute::CheckOptPreload.call(opts)
          Attribute::CheckOptSerializer.call(opts, block)
          Attribute::CheckOptValue.call(opts)
          Attribute::CheckOptBatch.call(self.class.serializer_class, opts)
        end

        def check_block
          Attribute::CheckBlock.call(block)
        end

        def allowed_opts_keys
          self.class.serializer_class.config.attribute_keys
        end

        def check_attribute_name
          self.class.serializer_class.config.check_attribute_name
        end
      end

      include InstanceMethods
      extend Serega::SeregaHelpers::SerializerClassHelper
    end
  end
end
