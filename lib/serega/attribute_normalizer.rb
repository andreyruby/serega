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
      # Shows normalized preloads for current attribute
      #
      # @return [Hash, nil] normalized preloads of current attribute
      #
      def preloads
        return @preloads if instance_variable_defined?(:@preloads)

        @preloads = prepare_preloads
      end

      #
      # Shows normalized preloads_path for current attribute
      #
      # @return [Array] normalized preloads_path of current attribute
      #
      def preloads_path
        return @preloads_path if instance_variable_defined?(:@preloads_path)

        @preloads_path = prepare_preloads_path
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

        case hide_setting
        when true
          return true
        when Array
          return true if hide_setting.include?(:preload) && preloads # hide when attribute has `:preload` option
          return true if hide_setting.include?(:batch) && batch_loaders.any? # hide when attribute has `:batch` option
        end

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

        if batch_opt.nil?
          []
        elsif batch_opt == true || batch_opt.respond_to?(:call)
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

      # Prepares preloads
      # @return [Hash,nil]
      #  - Nil means no need to add preloads and nested preloads
      #  - Hash with any keys will add preloads
      #  - Empty hash will skip only top-level preloads, but will allow to load nested preloads
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

      def prepare_preloads_path
        path = init_opts.fetch(:preload_path) { default_preload_path(preloads) }

        if path && path[0].is_a?(Array)
          prepare_many_preload_paths(path)
        else
          prepare_one_preload_path(path)
        end
      end

      def prepare_one_preload_path(path)
        return unless path

        case path
        when Array
          path.map(&:to_sym).freeze
        else
          [path.to_sym].freeze
        end
      end

      def prepare_many_preload_paths(paths)
        paths.map { |path| prepare_one_preload_path(path) }.freeze
      end

      def default_preload_path(preloads)
        return FROZEN_EMPTY_ARRAY if !preloads || preloads.empty?

        [preloads.keys.first]
      end
    end

    extend Serega::SeregaHelpers::SerializerClassHelper
    include AttributeNormalizerInstanceMethods
  end
end
