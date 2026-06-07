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
      # Identity loader that routes relation/preload attributes through the batch
      # mechanism. Its result is never read — the attribute's value block still
      # computes the value.
      AUTO_BATCH_LOADER = proc { |records| records.to_h { |record| [record, record] } }
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
      # Shows normalized preloads for current attribute
      #
      # @return [Hash, nil] normalized preloads of current attribute
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
        init_block \
          || init_opts[:value] \
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
        return true if hide_setting == :auto && (preloads || init_opts.key?(:batch))

        # Return nil for undefined value which means "not hide" but allows
        # to change this value by plugins
        nil
      end

      def config
        self.class.serializer_class.config
      end

      def prepare_many
        init_opts[:many]
      end

      def prepare_serializer
        init_opts[:serializer]
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

      def prepare_batch_loaders
        batch_opt = init_opts[:batch]
        return explicit_batch_loaders(batch_opt) if batch_opt
        return FROZEN_EMPTY_ARRAY unless serializer || preloads

        loader_name = :"__auto_batch_#{name}__"
        self.class.serializer_class.batch(loader_name, AUTO_BATCH_LOADER)
        [loader_name]
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

      # Prepares preloads for this attribute
      # @return [Hash, nil] preloads hash, or nil when the attribute has no preloads
      def prepare_preloads
        preload = init_opts[:preload]

        # Handle explicit preload option
        if init_opts.key?(:preload)
          return nil unless preload # return nil when false or nil
          return SeregaUtils::FormatUserPreloads.call(preload)
        end

        # Auto-preload for delegate
        if config.auto_preload.fetch(:has_delegate_option) && init_opts[:delegate]
          delegate_to = init_opts[:delegate][:to]
          return SeregaUtils::FormatUserPreloads.call(delegate_to)
        end

        # Auto-preload for serializer
        if config.auto_preload.fetch(:has_serializer_option) && init_opts[:serializer] && !init_opts.key?(:batch)
          return SeregaUtils::FormatUserPreloads.call(method_name)
        end

        nil
      end
    end

    extend Serega::SeregaHelpers::SerializerClassHelper
    include AttributeNormalizerInstanceMethods
  end
end
