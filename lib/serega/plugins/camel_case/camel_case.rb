# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin :camel_case
    #
    # CamelCases every attribute name automatically, replacing `_x` with `X`
    # throughout the string. Runs once, when the attribute is defined, not on
    # every serialization.
    #
    # Provide a custom transformation with
    # `plugin :camel_case, transform: ->(name) { name.camelize }`.
    #
    # Skip camelCase for a single attribute with `camel_case: false`.
    #
    # @example Define plugin
    #  class AppSerializer < Serega
    #    plugin :camel_case
    #  end
    #
    #  class UserSerializer < AppSerializer
    #    attribute :first_name
    #    attribute :last_name
    #    attribute :full_name, camel_case: false, value: proc { |user| [user.first_name, user.last_name].compact.join(" ") }
    #  end
    #
    #  require "ostruct"
    #  user = OpenStruct.new(first_name: "Bruce", last_name: "Wayne")
    #  UserSerializer.to_h(user) # {firstName: "Bruce", lastName: "Wayne", full_name: "Bruce Wayne"}
    #
    module CamelCase
      # Default camel-case transformation
      TRANSFORM_DEFAULT = proc { |attribute_name|
        attribute_name.gsub!(/_[a-z]/) { |m| m[-1].upcase! }
        attribute_name
      }

      # @return [Symbol] Plugin name
      # @private
      def self.plugin_name
        :camel_case
      end

      # Checks requirements to load plugin
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param opts [Hash] plugin options
      #
      # @return [void]
      #
      # @private
      def self.before_load_plugin(serializer_class, **opts)
        allowed_keys = %i[transform]
        opts.each_key do |key|
          next if allowed_keys.include?(key)

          raise SeregaError,
            "Plugin #{plugin_name.inspect} does not accept the #{key.inspect} option. Allowed options:\n" \
            "  - :transform [#call] - Custom transformation"
        end
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
        serializer_class::SeregaConfig.include(ConfigInstanceMethods)
        serializer_class::SeregaAttributeNormalizer.include(AttributeNormalizerInstanceMethods)
        serializer_class::CheckAttributeParams.include(CheckAttributeParamsInstanceMethods)
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
        config = serializer_class.config
        config.opts[:camel_case] = {}
        config.camel_case.transform = opts[:transform] || TRANSFORM_DEFAULT

        config.attribute_keys << :camel_case
      end

      #
      # Config class additional/patched instance methods
      #
      # @see Serega::SeregaConfig
      #
      module ConfigInstanceMethods
        # @return [Serega::SeregaPlugins::CamelCase::CamelCaseConfig] `camel_case` plugin config
        def camel_case
          @camel_case ||= CamelCaseConfig.new(opts.fetch(:camel_case))
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
          CheckOptCamelCase.call(opts)
        end
      end

      #
      # Validator for attribute :camel_case option
      #
      # @private
      class CheckOptCamelCase
        class << self
          #
          # Checks attribute :camel_case option must be boolean
          #
          # @param opts [Hash] Attribute options
          #
          # @raise [SeregaError] Attribute validation error
          #
          # @return [void]
          #
          def call(opts)
            camel_case_option_exists = opts.key?(:camel_case)
            return unless camel_case_option_exists

            value = opts[:camel_case]
            return if value.equal?(true) || value.equal?(false)

            raise SeregaError, "Attribute option :camel_case must have a boolean value, but #{value.class} was provided"
          end
        end
      end

      # CamelCase config object
      class CamelCaseConfig
        attr_reader :opts

        #
        # Initializes CamelCaseConfig object
        #
        # @param opts [Hash] camel_case plugin options
        # @option opts [#call] :transform Callable object that transforms original attribute name
        #
        # @return [Serega::SeregaPlugins::CamelCase::CamelCaseConfig] CamelCaseConfig object
        #
        def initialize(opts)
          @opts = opts
        end

        # @return [#call] defined object that transforms name
        def transform
          opts.fetch(:transform)
        end

        # Sets transformation callable object
        #
        # @param value [#call] transformation
        #
        # @return [#call] camel_case plugin transformation callable object
        def transform=(value)
          raise SeregaError, "Transform value must respond to #call" unless value.respond_to?(:call)

          params = value.is_a?(Proc) ? value.parameters : value.method(:call).parameters
          if params.count != 1 || !params.all? { |param| (param[0] == :req) || (param[0] == :opt) }
            raise SeregaError, "Transform value must respond to #call and accept 1 regular parameter"
          end

          opts[:transform] = value
        end
      end

      #
      # SeregaAttributeNormalizer additional/patched instance methods
      #
      # @see SeregaAttributeNormalizer::AttributeInstanceMethods
      #
      # @private
      module AttributeNormalizerInstanceMethods
        private

        #
        # Patch for original `prepare_name` method
        #
        # Makes camelCased name
        #
        def prepare_name
          res = super
          return res if init_opts[:camel_case] == false

          self.class.serializer_class.config.camel_case.transform.call(+res.to_s).to_sym
        end
      end
    end

    register_plugin(CamelCase.plugin_name, CamelCase)
  end
end
