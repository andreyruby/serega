# frozen_string_literal: true

class Serega
  module SeregaPlugins
    # Plugin `:camel_case`: serializes attribute keys in camelCase. The
    # `camel_case: false` attribute option keeps a name as is, and the
    # `transform:` plugin option sets the transformation.
    #
    # ```ruby
    # plugin :camel_case
    # plugin :camel_case, transform: ->(name) { name.camelize(:lower) }
    # ```
    #
    # See [Plugin :camel_case](https://github.com/andreyruby/serega/blob/master/docs/plugins.md#plugin-camel_case).
    module CamelCase
      # Default camel-case transformation
      TRANSFORM_DEFAULT = proc { |attribute_name| # :nodoc:
        attribute_name.gsub!(/_[a-z]/) { |m| m[-1].upcase! }
        attribute_name
      }

      # @return [Symbol] Plugin name
      def self.plugin_name # :nodoc:
        :camel_case
      end

      # Checks requirements to load plugin
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param opts [Hash] plugin options
      #
      # @return [void]
      def self.before_load_plugin(serializer_class, **opts) # :nodoc:
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
      def self.load_plugin(serializer_class, **_opts) # :nodoc:
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
      def self.after_load_plugin(serializer_class, **opts) # :nodoc:
        config = serializer_class.config
        config.opts[:camel_case] = {}
        config.camel_case.transform = opts[:transform] || TRANSFORM_DEFAULT

        config.attribute_keys << :camel_case
      end

      # Config methods the plugin adds to Serega::SeregaConfig
      module ConfigInstanceMethods
        # Config of the plugin
        def camel_case
          @plugin_configs[:camel_case] ||= CamelCaseConfig.new(opts.fetch(:camel_case))
        end

        # Builds the camel_case config before freezing
        def freeze # :nodoc:
          camel_case
          super
        end
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
          CheckOptCamelCase.call(opts)
        end
      end

      #
      # Validator for attribute :camel_case option
      #
      class CheckOptCamelCase # :nodoc:
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

      # Config of the `:camel_case` plugin, `config.camel_case`
      class CamelCaseConfig
        attr_reader :opts # :nodoc:

        #
        # Initializes CamelCaseConfig object
        #
        # @param opts [Hash] camel_case plugin options
        # @option opts [#call] :transform Callable object that transforms original attribute name
        #
        # @return [Serega::SeregaPlugins::CamelCase::CamelCaseConfig] CamelCaseConfig object
        #
        def initialize(opts) # :nodoc:
          @opts = opts
        end

        # Callable that transforms an attribute name String
        def transform
          opts.fetch(:transform)
        end

        # Sets #transform, a callable with one parameter
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
      module AttributeNormalizerInstanceMethods # :nodoc:
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
