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

      # Options that can't be given together, `block` for the attribute
      # block. Each option lists every option it conflicts with, and the error
      # names the option that comes first here. :hash_access with :delegate is
      # left to CheckOptHashAccess, which points to the delegate sub-options.
      CONFLICTS = {
        method: %i[value const delegate batch],
        value: %i[method const delegate hash_access],
        const: %i[method value delegate batch hash_access preload],
        delegate: %i[method value const batch],
        batch: %i[method const delegate hash_access],
        hash_access: %i[value const batch],
        preload: %i[const],
        serializer: %i[block if_value unless_value],
        if_value: %i[serializer block],
        unless_value: %i[serializer block]
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
        Attribute::CheckOptSerializer.call(opts)
        Attribute::CheckOptValue.call(opts)
        Attribute::CheckOptBatch.call(@serializer_class, name, opts)
      end

      def check_block
        Attribute::CheckBlock.call(block)
      end

      def check_conflicts
        CONFLICTS.each do |option, others|
          next unless opts.key?(option)

          other = others.find { |key| (key == :block) ? block : opts.key?(key) }
          raise SeregaError, conflict_message(option, other) if other
        end
      end

      def conflict_message(option, other)
        return "Option #{option.inspect} can not be used together with block" if other == :block

        "Option #{option.inspect} can not be used together with option #{other.inspect}"
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
