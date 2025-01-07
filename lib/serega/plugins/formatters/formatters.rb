# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin :formatters
    #
    # Allows to define value formatters one time and apply them on any attributes.
    #
    # Config option `config.formatters.add()` can be used to add formatters.
    #
    # Attribute option `:format` now can be used with name of formatter or with callable instance.
    #
    # Formatters can accept up to 2 parameters (formatted object, context)
    #
    # @example
    #   class AppSerializer < Serega
    #     plugin :formatters, formatters: {
    #       iso8601: ->(value) { time.iso8601.round(6) },
    #       on_off: ->(value) { value ? 'ON' : 'OFF' },
    #       money: ->(value) { value.round(2) }
    #       date: DateTypeFormatter # callable
    #     }
    #   end
    #
    #   class UserSerializer < Serega
    #     # Additionally we can add formatters via config in subclasses
    #     config.formatters.add(
    #       iso8601: ->(value) { time.iso8601.round(6) },
    #       on_off: ->(value) { value ? 'ON' : 'OFF' },
    #       money: ->(value) { value.round(2) }
    #     )
    #
    #     # Using predefined formatter
    #     attribute :commission, format: :money
    #     attribute :is_logined, format: :on_off
    #     attribute :created_at, format: :iso8601
    #     attribute :updated_at, format: :iso8601
    #
    #     # Using `callable` formatter
    #     attribute :score_percent, format: PercentFormmatter # callable class
    #     attribute :score_percent, format: proc { |percent| "#{percent.round(2)}%" }
    #   end
    #
    module Formatters
      # @return [Symbol] Plugin name
      def self.plugin_name
        :formatters
      end

      # Checks requirements and loads additional plugins
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param opts [Hash] Plugin options
      #
      # @return [void]
      #
      def self.before_load_plugin(serializer_class, **opts)
        allowed_keys = %i[formatters]
        opts.each_key do |key|
          next if allowed_keys.include?(key)

          raise SeregaError,
            "Plugin #{plugin_name.inspect} does not accept the #{key.inspect} option. Allowed options:\n" \
            "  - :formatters [Hash<Symbol, #call>] - Formatters (names and according callable values)"
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
      def self.load_plugin(serializer_class, **_opts)
        serializer_class::SeregaConfig.include(ConfigInstanceMethods)
        serializer_class::SeregaAttributeNormalizer.include(AttributeNormalizerInstanceMethods)
        serializer_class::SeregaAttribute.include(AttributeInstanceMethods)
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
      def self.after_load_plugin(serializer_class, **opts)
        config = serializer_class.config
        config.opts[:formatters] = {}
        config.formatters.add(opts[:formatters] || {})
        config.attribute_keys << :format
      end

      # Formatters plugin config
      class FormattersConfig
        attr_reader :opts

        #
        # Initializes formatters config object
        #
        # @param opts [Hash] options
        #
        # @return FormattersConfig
        def initialize(opts)
          @opts = opts
        end

        # Adds new formatters
        #
        # @param formatters [Hash<Symbol, #call>] hash key is a formatter name and
        #   hash value is a callable instance to format value
        #
        # @return [void]
        def add(formatters)
          formatters.each_pair do |key, value|
            CheckFormatter.call(key, value)
            opts[key] = value
          end
        end
      end

      #
      # Config class additional/patched instance methods
      #
      # @see SeregaConfig
      #
      module ConfigInstanceMethods
        # @return [SeregaPlugins::Formatters::FormattersConfig] current formatters config
        def formatters
          @formatters ||= FormattersConfig.new(opts.fetch(:formatters))
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

          CheckOptFormat.call(opts, self.class.serializer_class)
        end
      end

      #
      # AttributeNormalizer class additional/patched instance methods
      #
      # @see SeregaAttributeNormalizer
      #
      module AttributeNormalizerInstanceMethods
        # Block or callable instance that will format attribute values
        # @return [Proc, #call, nil] Block or callable instance that will format attribute values
        def formatter
          @formatter ||= prepare_formatter
        end

        #
        # Returns formatter method signature for optimized calling
        #
        # @return [String, nil] Formatter signature ("1", "2", "1_ctx") or nil if no formatter
        #
        def formatter_signature
          @formatter_signature ||= prepare_formatter_signature
        end

        private

        def prepare_formatter
          formatter = init_opts[:format]
          return unless formatter

          formatter = self.class.serializer_class.config.formatters.opts.fetch(formatter) if formatter.is_a?(Symbol)
          formatter
        end

        def prepare_formatter_signature
          return unless formatter

          SeregaUtils::MethodSignature.call(formatter, pos_limit: 2, keyword_args: [:ctx])
        end
      end

      #
      # Attribute class additional/patched instance methods
      #
      # @see SeregaAttribute
      #
      module AttributeInstanceMethods
        #
        # Returns formatted attribute value
        #
        # @param object [Object] Serialized object
        # @param context [Hash] Serialization context
        #
        # @return [Object] Formatted attribute value
        #
        def value(object, context, batches: nil)
          result = super # `:batches` parameter is needed to find unformatted result
          return result unless formatter

          case formatter_signature
          when "1" then formatter.call(result)
          when "1_ctx" then formatter.call(result, ctx: context)
          else # "2"
            formatter.call(result, context)
          end
        end

        private

        attr_reader :formatter, :formatter_signature

        def set_normalized_vars(normalizer)
          super
          @formatter = normalizer.formatter
          @formatter_signature = normalizer.formatter_signature
        end
      end

      #
      # Validator for attribute :format option
      #
      class CheckOptFormat
        class << self
          #
          # Checks attribute :format option must be registered or valid callable with maximum 2 args
          #
          # @param opts [value] Attribute options
          #
          # @raise [SeregaError] Attribute validation error
          #
          # @return [void]
          #
          def call(opts, serializer_class)
            return unless opts.key?(:format)

            formatter = opts[:format]

            if formatter.is_a?(Symbol)
              check_formatter_defined(serializer_class, formatter)
            else
              CheckFormatter.call(:format, formatter)
            end
          end

          private

          def check_formatter_defined(serializer_class, formatter)
            return if serializer_class.config.formatters.opts.key?(formatter)

            raise Serega::SeregaError, "Formatter `#{formatter.inspect}` was not defined"
          end
        end
      end

      #
      # Validator for formatters defined as config options or directly as attribute :format option
      #
      class CheckFormatter
        class << self
          #
          # Check formatter type and parameters
          #
          # @param formatter_name [Symbol] Name of formatter
          # @param formatter [#call] Formatter callable object
          #
          # @return [void]
          #
          def call(formatter_name, formatter)
            raise Serega::SeregaError, "Option #{formatter_name.inspect} must have callable value" unless formatter.respond_to?(:call)

            signature = SeregaUtils::MethodSignature.call(formatter, pos_limit: 2, keyword_args: [:ctx])
            raise SeregaError, signature_error unless valid_signature?(signature)
          end

          private

          def valid_signature?(signature)
            case signature
            when "1"      # (object)
              true
            when "2"      # (object, context)
              true
            when "1_ctx"  # (object, :ctx)
              true
            else
              false
            end
          end

          def signature_error
            <<~ERROR.strip
              Invalid formatter parameters, valid parameters signatures:
              - (object)          # one positional parameter
              - (object, context) # two positional parameters
              - (object, :ctx)    # one positional parameter and :ctx keyword
            ERROR
          end
        end
      end
    end

    register_plugin(Formatters.plugin_name, Formatters)
  end
end
