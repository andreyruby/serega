# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin :if
    #
    # Adds `:if`, `:unless`, `:if_value`, `:unless_value` attribute options to
    # conditionally remove attributes from the response.
    #
    # `:if`/`:unless` receive the serialized object and context, and are
    # checked before the attribute value is found. `:if_value`/`:unless_value`
    # receive the already-found value and context, checked after. The latter
    # two cannot be used with the `:serializer` option, since a relationship
    # has no "serialized value" of its own — use `:if`/`:unless` instead.
    #
    # `to_h` omits skipped attributes. `to_data` and `to_struct` return `nil`
    # for skipped attributes.
    #
    # See also the plugin-free `:hide` option (README.md#selecting-fields),
    # which hides an attribute unconditionally.
    #
    # @example
    #   class UserSerializer < Serega
    #     attribute :email, if: :active? # if user.active?
    #     attribute :email, if: proc { |user, ctx| user == ctx[:current_user] } # using context
    #     attribute :email, if: CustomPolicy.method(:view_email?) # any callable
    #
    #     attribute :email, unless: :hidden? # unless user.hidden?
    #     attribute :email, if_value: :present? # if email.present?
    #     attribute :email, unless_value: :blank? # unless email.blank?
    #   end
    #
    module If
      # @return [Symbol] Plugin name
      # @private
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
      # @private
      def self.load_plugin(serializer_class, **_opts)
        require_relative "validations/check_opt_if"
        require_relative "validations/check_opt_if_value"
        require_relative "validations/check_opt_unless"
        require_relative "validations/check_opt_unless_value"

        serializer_class::SeregaAttribute.include(AttributeInstanceMethods)
        serializer_class::SeregaAttributeNormalizer.include(AttributeNormalizerInstanceMethods)
        serializer_class::SeregaResultShape.include(ResultShapeInstanceMethods)
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
      # @private
      def self.after_load_plugin(serializer_class, **opts)
        serializer_class.config.attribute_keys << :if << :if_value << :unless << :unless_value
      end

      #
      # SeregaAttributeNormalizer additional/patched instance methods
      #
      # @see SeregaAttributeNormalizer::AttributeInstanceMethods
      #
      # @private
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
          return KeywordConditionResolver.new(if_option) if if_option.is_a?(Symbol)

          if_option
        end
      end

      #
      # Resolves keyword-based conditions for if/unless options
      #
      # @private
      class KeywordConditionResolver
        def initialize(keyword)
          @keyword = keyword
        end

        #
        # Calls the keyword method on the object
        #
        # @param object [Object] the object to call method on
        # @return [Object] result of method call
        #
        def call(object)
          object.public_send(@keyword)
        end
      end

      #
      # SeregaAttribute additional/patched instance methods
      #
      # @see Serega::SeregaAttribute
      #
      # @private
      module AttributeInstanceMethods
        # @return [Hash] provided :if options
        attr_reader :opt_if

        # @return [Hash] signatures for provided :if options
        attr_reader :opt_if_signatures

        # @return [Boolean] Whether attribute has any :if/:unless/:if_value/:unless_value condition
        def conditional?
          @conditional
        end

        private

        def set_normalized_vars(normalizer)
          super
          @opt_if = normalizer.if_options
          @opt_if_signatures = normalizer.if_options_signatures
          @conditional = @opt_if.any? { |_option_name, condition| condition }
        end
      end

      #
      # Serega::SeregaResultShape additional/patched instance methods
      #
      # @see Serega::SeregaResultShape::InstanceMethods
      #
      # @private
      module ResultShapeInstanceMethods
        #
        # Instantiates new result shape and prepares a template of :data
        # containers when the plan has conditional attributes
        #
        # @see Serega::SeregaResultShape::InstanceMethods#initialize
        #
        def initialize(mode, points)
          super
          conditional = mode == :data && points.any?(&:conditional?)
          @nil_hash = conditional ? points.to_h { |point| [point.name, nil] }.freeze : nil
        end

        #
        # Builds :data containers of plans with conditional attributes with all
        # attribute names and nil values, so skipped attributes stay nil.
        #
        # @param count [Integer] Number of containers
        #
        # @return [Array<Hash, Struct>] Empty containers
        #
        def build_containers(count)
          template = @nil_hash
          return super unless template

          Array.new(count) { template.dup }
        end
      end

      #
      # Serega::SeregaPlanPoint additional/patched instance methods
      #
      # @see Serega::SeregaPlanPoint::InstanceMethods
      #
      # @private
      module PlanPointInstanceMethods
        #
        # @return [Boolean] Whether attribute has any :if/:unless/:if_value/:unless_value condition
        #
        def conditional?
          attribute.conditional?
        end

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
          when "2_ctx" then condition.call(object, context, ctx: context)
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
      # @private
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
      # @private
      module ObjectSerializerInstanceMethods
        private

        def process_point(point, objects, containers, batches, child_serializer)
          return super unless point.conditional?

          attribute = point.attribute
          name = point.name
          context = @context
          index = 0
          size = objects.size

          while index < size
            object = objects[index]

            if point.satisfy_if_conditions?(object, context)
              value = attribute.value(object, context, batches: batches)
              final_value = child_serializer ? child_serializer.serialize(value) : value
              containers[index][name] = final_value if point.satisfy_if_value_conditions?(final_value, context)
            end

            index += 1
          end
        rescue => error
          SeregaUtils::SerializedAttributeError.call(error, point)
        end
      end
    end

    register_plugin(If.plugin_name, If)
  end
end
