# frozen_string_literal: true

class Serega
  #
  # Prepares provided attribute options
  #
  class SeregaAttributeNormalizer
    #
    # AttributeNormalizer instance methods
    #
    module AttributeNormalizerInstanceMethods
      # Attribute initial params
      # @return [Hash] Attribute initial params
      attr_reader :init_name, :init_opts, :init_block

      #
      # Instantiates attribute options normalizer
      #
      # @param initials [Hash] new attribute options
      #
      # @return [SeregaAttributeNormalizer] Instantiated attribute options normalizer
      #
      def initialize(initials)
        @init_name = initials[:name]
        @init_opts = initials[:opts]
        @init_block = initials[:block]
      end

      #
      # Symbolized initial attribute name
      #
      # @return [Symbol] Attribute normalized name
      #
      def name
        @name ||= prepare_name
      end

      #
      # Symbolized initial attribute method name
      #
      # @return [Symbol] Attribute normalized method name
      #
      def method_name
        @method_name ||= prepare_method_name
      end

      #
      # Combines all options to return single block that will be used to find
      # attribute value during serialization
      #
      # @return [#call] Attribute normalized callable value block
      #
      def value_block
        @value_block ||= prepare_value_block
      end

      #
      # Detects value block parameters signature
      #
      # @return [String] value block parameters signature
      #
      def value_block_signature
        @value_block_signature ||= SeregaUtils::MethodSignature.call(value_block, pos_limit: 2, keyword_args: [:ctx])
      end

      #
      # Shows if attribute is specified to be hidden
      #
      # @return [Boolean, nil] if attribute must be hidden by default
      #
      def hide
        return @hide if instance_variable_defined?(:@hide)

        @hide = prepare_hide
      end

      #
      # Shows if attribute is specified to be a one-to-many relationship
      #
      # @return [Boolean, nil] if attribute is specified to be a one-to-many relationship
      #
      def many
        return @many if instance_variable_defined?(:@many)

        @many = prepare_many
      end

      #
      # Shows specified attribute serializer
      # @return [Serega, String, #callable, nil] specified serializer
      #
      def serializer
        return @serializer if instance_variable_defined?(:@serializer)

        @serializer = prepare_serializer
      end

      #
      # Shows the default attribute value. It is a value that replaces found nils.
      #
      # When custom :default is not specified, we set empty array as default when `many: true` specified
      #
      # @return [Object] Attribute default value
      #
      def default
        return @default if instance_variable_defined?(:@default)

        @default = prepare_default
      end

      #
      # Preloads declared for this attribute, passed through as provided.
      #
      # @return [Object, nil] declared preloads, or nil when the attribute has none
      #
      def preloads
        return @preloads if instance_variable_defined?(:@preloads)

        @preloads = prepare_preloads
      end

      # Shows specified batch loaders names
      # @return [Array<Symbol>] specified serializer
      #
      def batch_loaders
        @batch_loaders ||= prepare_batch_loaders
      end

      private

      def prepare_name
        init_name.to_sym
      end

      def prepare_value_block
        init_opts[:value] \
          || prepare_const_block \
          || prepare_delegate_block \
          || prepare_batch_loader_block \
          || prepare_keyword_block
      end

      def prepare_hide
        # Return provided directly value
        hide = init_opts[:hide]
        return hide if (hide == true) || (hide == false)

        hide_setting = config.hide_by_default
        return true if hide_setting == true
        return true if hide_setting == :auto && preload_or_batch?

        # Return nil for undefined value which means "not hide" but allows
        # to change this value by plugins
        nil
      end

      # The `hide_by_default = :auto` criterion: hide attributes that fetch extra
      # data on demand — those declared with `:preload` or an explicit `:batch`.
      #
      # This is intentionally narrower than a "goes through the batch mechanism"
      # check (`SeregaPlanPoint#batch?`): a plain relation (`serializer:` without
      # `:preload`) is batch-processed too, but it only serializes an already-loaded
      # nested object, so it stays visible by default.
      def preload_or_batch?
        !!(preloads || init_opts.key?(:batch))
      end

      def config
        self.class.serializer_class.config
      end

      def prepare_many
        init_opts[:many]
      end

      def prepare_serializer
        block = init_block
        return init_opts[:serializer] unless block

        prepare_block_serializer(block)
      end

      # Builds an anonymous nested serializer from the attribute block.
      #
      # The serializer is a regular subclass of an explicitly chosen base —
      # the :base_serializer attribute option or `config.base_serializer` —
      # so it inherits everything the base has: plugins, config, attributes,
      # batch loaders, the preload handler. Nested values can be any objects,
      # which is why the base is chosen explicitly instead of inheriting from
      # the current serializer. Its `inspect` is overridden to
      # `CurrentSerializer.<attribute_name>` so error messages and debugging
      # output point back to the defining attribute.
      def prepare_block_serializer(block)
        label = "#{self.class.serializer_class.inspect}.<#{name}>"

        serializer = Class.new(block_base_serializer) do
          define_singleton_method(:inspect) { label }
          define_singleton_method(:to_s) { label }
          instance_exec(&block)
        end

        # An empty nested serializer means the block was intended as an
        # old-style value block — raise the explaining error.
        raise SeregaError, SeregaValidations::Attribute::CheckBlock::ERROR_MESSAGE if serializer.attributes.empty?

        serializer
      end

      # Base class for the nested serializer. Must be chosen explicitly —
      # usually a settings-only serializer holding plugins and configuration
      # (e.g. `config.base_serializer = self` in an application base class).
      def block_base_serializer
        base_serializer = init_opts[:base_serializer] || config.base_serializer
        return base_serializer if base_serializer

        raise SeregaError,
          "Attribute block requires a base serializer for the nested serializer." \
          " Provide the `base_serializer: <SerializerClass>` attribute option" \
          " or set `config.base_serializer = <SerializerClass>`"
      end

      def prepare_method_name
        (init_opts[:method] || init_name).to_sym
      end

      def prepare_const_block
        return unless init_opts.key?(:const)

        AttributeValueResolvers::ConstResolver.get(init_opts[:const])
      end

      def prepare_keyword_block
        AttributeValueResolvers::KeywordResolver.get(method_name)
      end

      def prepare_batch_loader_block
        batch_opt = init_opts[:batch]
        return unless batch_opt

        AttributeValueResolvers::BatchResolver.get(self.class.serializer_class, name, batch_opt)
      end

      # Batch loader names whose loaded data this attribute's value needs. Only
      # explicit `:batch` attributes have any — everything else resolves its value
      # from the record itself, so the list is empty (no loader to run).
      def prepare_batch_loaders
        batch_opt = init_opts[:batch]
        return explicit_batch_loaders(batch_opt) if batch_opt

        FROZEN_EMPTY_ARRAY
      end

      def explicit_batch_loaders(batch_opt)
        if batch_opt == true || batch_opt.respond_to?(:call)
          [name]
        elsif batch_opt.is_a?(Symbol)
          [batch_opt]
        elsif batch_opt.is_a?(String)
          [batch_opt.to_sym]
        else
          use_opt = batch_opt.fetch(:use)
          use_opt.respond_to?(:call) ? [name] : Array(use_opt).map(&:to_sym)
        end
      end

      def prepare_default
        init_opts.fetch(:default) { many ? FROZEN_EMPTY_ARRAY : nil }
      end

      def prepare_delegate_block
        delegate = init_opts[:delegate]
        return unless delegate

        key_method_name = delegate[:method] || method_name
        delegate_to = delegate[:to]

        allow_nil = delegate.fetch(:allow_nil) { config.delegate_default_allow_nil }
        AttributeValueResolvers::DelegateResolver.get(delegate_to, key_method_name, allow_nil)
      end

      # Prepares preloads for this attribute.
      #
      # The value is passed through as provided (Symbol, Array, Hash, or any
      # custom value an ORM understands) — it is the data handed to the
      # serializer's `preload_with` handler.
      #
      # @return [Object, nil] preloads as provided, or nil when the attribute has none
      def prepare_preloads
        # Explicit preload option (false or nil disables preloading)
        return init_opts[:preload] || nil if init_opts.key?(:preload)

        # Auto-preload the delegated association
        if config.auto_preload.fetch(:has_delegate_option) && init_opts[:delegate]
          return init_opts[:delegate][:to]
        end

        # Auto-preload the nested serializer's association
        # (a block defines a nested serializer, same as the :serializer option)
        if config.auto_preload.fetch(:has_serializer_option) && (init_opts[:serializer] || init_block) && !init_opts.key?(:batch)
          return method_name
        end

        nil
      end
    end

    extend Serega::SeregaHelpers::SerializerClassHelper
    include AttributeNormalizerInstanceMethods
  end
end
