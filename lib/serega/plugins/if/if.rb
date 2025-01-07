# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin adds `:if`, `:unless`, `:if_value`, `:unless_value` options to
    # attributes so we can remove attributes from response in various ways.
    #
    # Use `:if` and `:unless` when you want to hide attributes before finding attribute value,
    # and use `:if_value` and `:unless_value` to hide attributes after we find final value.
    #
    # Options `:if` and `:unless` accept currently serialized object and context as parameters.
    # Options `:if_value` and `:unless_value` accept already found serialized value and context as parameters.
    #
    # Options `:if_value` and `:unless_value` cannot be used with :serializer option, as
    # serialized objects have no "serialized value". Use `:if` and `:unless` in this case.
    #
    # See also a `:hide` option that is available without any plugins to hide
    # attribute without conditions. Look at README.md#selecting-fields for `:hide` usage examples.
    #
    # Examples:
    #  class UserSerializer < Serega
    #    attribute :email, if: :active? # if user.active?
    #    attribute :email, if: proc {|user| user.active?} # same
    #    attribute :email, if: proc {|user, ctx| user == ctx[:current_user]} # using context
    #    attribute :email, if: CustomPolicy.method(:view_email?) # You can provide own callable object
    #
    #    attribute :email, unless: :hidden? # unless user.hidden?
    #    attribute :email, unless: proc {|user| user.hidden?} # same
    #    attribute :email, unless: proc {|user, context| context[:show_emails]} # using context
    #    attribute :email, unless: CustomPolicy.method(:hide_email?) # You can provide own callable object
    #
    #    attribute :email, if_value: :present? # if email.present?
    #    attribute :email, if_value: proc {|email| email.present?} # same
    #    attribute :email, if_value: proc {|email, ctx| ctx[:show_emails]} # using context
    #    attribute :email, if_value: CustomPolicy.method(:view_email?) # You can provide own callable object
    #
    #    attribute :email, unless_value: :blank? # unless email.blank?
    #    attribute :email, unless_value: proc {|email| email.blank?} # same
    #    attribute :email, unless_value: proc {|email, context| context[:show_emails]} # using context
    #    attribute :email, unless_value: CustomPolicy.method(:hide_email?) # You can provide own callable object
    #  end
    #
    module If
      # This value must be returned to identify that serialization key was skipped
      KEY_SKIPPED = :_key_skipped_with_serega_if_plugin

      # @return [Symbol] Plugin name
      def self.plugin_name
        :if
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
        require_relative "validations/check_opt_if"
        require_relative "validations/check_opt_if_value"
        require_relative "validations/check_opt_unless"
        require_relative "validations/check_opt_unless_value"

        serializer_class::SeregaAttribute.include(AttributeInstanceMethods)
        serializer_class::SeregaAttributeNormalizer.include(AttributeNormalizerInstanceMethods)
        serializer_class::SeregaPlanPoint.include(PlanPointInstanceMethods)
        serializer_class::CheckAttributeParams.include(CheckAttributeParamsInstanceMethods)
        serializer_class::SeregaObjectSerializer.include(ObjectSerializerInstanceMethods)
      end

      #
      # Adds config options and runs other callbacks after plugin was loaded
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param opts [Hash] Plugin options
      #
      # @return [void]
      #
      def self.after_load_plugin(serializer_class, **opts)
        serializer_class.config.attribute_keys << :if << :if_value << :unless << :unless_value
      end

      #
      # SeregaAttributeNormalizer additional/patched instance methods
      #
      # @see SeregaAttributeNormalizer::AttributeInstanceMethods
      #
      module AttributeNormalizerInstanceMethods
        #
        # Returns prepared attribute :if_options.
        #
        # @return [Hash] prepared options for :if plugin
        #
        def if_options
          @if_options ||= {
            if: prepare_if_option(init_opts[:if]),
            unless: prepare_if_option(init_opts[:unless]),
            if_value: prepare_if_option(init_opts[:if_value]),
            unless_value: prepare_if_option(init_opts[:unless_value])
          }.freeze
        end

        #
        # Returns method signatures for all if options for optimized calling
        #
        # @return [Hash] Hash with signatures for each if option type
        #
        def if_options_signatures
          @if_options_signatures ||= {
            if: if_option_signature(:if),
            unless: if_option_signature(:unless),
            if_value: if_option_signature(:if_value),
            unless_value: if_option_signature(:unless_value)
          }.freeze
        end

        private

        def if_option_signature(option_name)
          callable = if_options[option_name]
          return unless callable

          SeregaUtils::MethodSignature.call(callable, pos_limit: 2, keyword_args: [:ctx])
        end

        def prepare_if_option(if_option)
          return unless if_option
          return proc { |val| val.public_send(if_option) } if if_option.is_a?(Symbol)

          if_option
        end
      end

      #
      # SeregaAttribute additional/patched instance methods
      #
      # @see Serega::SeregaAttribute
      #
      module AttributeInstanceMethods
        # @return [Hash] provided :if options
        attr_reader :opt_if

        # @return [Hash] signatures for provided :if options
        attr_reader :opt_if_signatures

        private

        def set_normalized_vars(normalizer)
          super
          @opt_if = normalizer.if_options
          @opt_if_signatures = normalizer.if_options_signatures
        end
      end

      #
      # Serega::SeregaPlanPoint additional/patched instance methods
      #
      # @see Serega::SeregaPlanPoint::InstanceMethods
      #
      module PlanPointInstanceMethods
        #
        # @return [Boolean] Should we show attribute or not
        #   Conditions for this checks are specified by :if and :unless attribute options.
        #
        def satisfy_if_conditions?(obj, ctx)
          check_if_unless(obj, ctx, :if, :unless)
        end

        #
        # @return [Boolean] Should we show attribute with specific value or not.
        #   Conditions for this checks are specified by :if_value and :unless_value attribute options.
        #
        def satisfy_if_value_conditions?(value, ctx)
          check_if_unless(value, ctx, :if_value, :unless_value)
        end

        private

        def check_if_unless(obj, ctx, opt_if_name, opt_unless_name)
          opt_if = attribute.opt_if[opt_if_name]
          opt_unless = attribute.opt_if[opt_unless_name]
          return true if opt_if.nil? && opt_unless.nil?

          res_if = opt_if ? check_condition(opt_if, opt_if_name, obj, ctx) : true
          res_unless = opt_unless ? !check_condition(opt_unless, opt_unless_name, obj, ctx) : true
          res_if && res_unless
        end

        def check_condition(condition, condition_name, object, context)
          signature = attribute.opt_if_signatures[condition_name]

          case signature
          when "1" then condition.call(object)
          when "2" then condition.call(object, context)
          when "1_ctx" then condition.call(object, ctx: context)
          else # "0"
            condition.call
          end
        end
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

          CheckOptIf.call(opts)
          CheckOptUnless.call(opts)
          CheckOptIfValue.call(opts)
          CheckOptUnlessValue.call(opts)
        end
      end

      #
      # SeregaObjectSerializer additional/patched class methods
      #
      # @see Serega::SeregaObjectSerializer
      #
      module ObjectSerializerInstanceMethods
        private

        def serialize_point(object, point, _container)
          return KEY_SKIPPED unless point.satisfy_if_conditions?(object, context)
          super
        end

        def attach_final_value(value, point, _container)
          return KEY_SKIPPED unless point.satisfy_if_value_conditions?(value, context)

          super
        end
      end
    end

    register_plugin(If.plugin_name, If)
  end
end
