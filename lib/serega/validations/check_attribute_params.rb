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
      # Options of `Serega.attribute`
      ATTRIBUTE_KEYS = %i[
        method value serializer many hide const delegate default format preload batch
        base_serializer hash_access if unless if_value unless_value
      ].freeze

      # Options that can't be given together. Each pair is listed once, under
      # the option that the error names first.
      CONFLICTS = {
        if_value: %i[serializer],
        unless_value: %i[serializer],
        const: %i[method value batch],
        delegate: %i[method const value batch],
        hash_access: %i[const value batch],
        method: %i[value batch],
        preload: %i[const]
      }.freeze

      # Validated attribute name
      attr_reader :name

      # Validated attribute options
      attr_reader :opts

      # Validated attribute block
      attr_reader :block

      # Initializes attribute params validator
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
        Utils::CheckAllowedKeys.call(opts, ATTRIBUTE_KEYS, :attribute)
        check_conflicts

        Attribute::CheckOptBaseSerializer.call(opts, block)
        Attribute::CheckOptCondition.call(opts, :if)
        Attribute::CheckOptCondition.call(opts, :unless)
        Attribute::CheckOptCondition.call(opts, :if_value)
        Attribute::CheckOptCondition.call(opts, :unless_value)
        Attribute::CheckOptDelegate.call(opts)
        Attribute::CheckOptFormat.call(opts, @serializer_class)
        Attribute::CheckOptHashAccess.call(opts)
        Attribute::CheckOptHide.call(opts)
        Attribute::CheckOptMethod.call(opts)
        Attribute::CheckOptMany.call(opts, block, require_many)
        Attribute::CheckOptPreload.call(opts)
        Attribute::CheckOptSerializer.call(opts, block)
        Attribute::CheckOptValue.call(opts)
        Attribute::CheckOptBatch.call(@serializer_class, name, opts)
      end

      def check_block
        Attribute::CheckBlock.call(block)
      end

      def check_conflicts
        CONFLICTS.each do |option, others|
          next unless opts.key?(option)

          other = others.find { |key| opts.key?(key) }
          raise SeregaError, "Option #{option.inspect} can not be used together with option #{other.inspect}" if other
        end
      end

      def check_attribute_name
        @serializer_class.config.check_attribute_name
      end

      def require_many
        @serializer_class.config.require_many
      end
    end
  end
end
