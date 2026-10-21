# frozen_string_literal: true

class Serega
  module SeregaPlugins
    # `plugin :root` wraps results in a root key, `:data` by default
    #
    # ```ruby
    # plugin :root                                     # {data: ...}
    # plugin :root, root: :users                       # one key for objects and lists
    # plugin :root, root_one: :user, root_many: :users # separate keys
    #
    # UserSerializer.to_h(user, root: :user) # => {user: {username: "batman"}}
    # UserSerializer.to_h(user, root: nil)   # => {username: "batman"}
    # ```
    #
    # See [Root key](https://github.com/andreyruby/serega/blob/master/docs/root-and-metadata.md#root-key).
    module Root
      # @return [Symbol] Default response root key
      ROOT_DEFAULT = :data # :nodoc:

      # @return [Symbol] Plugin name
      def self.plugin_name # :nodoc:
        :root
      end

      # Checks requirements to load plugin
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param opts [Hash] plugin options
      #
      # @return [void]
      def self.before_load_plugin(serializer_class, **opts) # :nodoc:
        allowed_keys = %i[root root_one root_many]
        opts.each_key do |key|
          next if allowed_keys.include?(key)

          raise SeregaError,
            "Plugin #{plugin_name.inspect} does not accept the #{key.inspect} option. Allowed options:\n" \
            "  - :root [String, Symbol, nil] Specifies common root keyword used when serializing one or multiple objects\n" \
            "  - :root_one [String, Symbol, nil] Specifies root keyword used when serializing one object\n" \
            "  - :root_many [String, Symbol, nil] Specifies root keyword used when serializing multiple objects" \
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
        serializer_class.extend(ClassMethods)
        serializer_class.include(InstanceMethods)
        serializer_class::SeregaConfig.include(ConfigInstanceMethods)
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
        default = opts.fetch(:root, ROOT_DEFAULT)
        one = opts.fetch(:root_one, default)
        many = opts.fetch(:root_many, default)
        config.opts[:root] = {}
        config.root = {one: one, many: many}

        config.serialize_keys << :root
      end

      # Class methods the plugin adds to serializers
      module ClassMethods
        # @see Serega::ClassMethods#call
        def call(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil, **opts) # :nodoc:
          new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
            .to_h(object, context: context, many: many, **opts)
        end

        # @see Serega::ClassMethods#to_data
        def to_data(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil, **opts) # :nodoc:
          new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
            .to_data(object, context: context, many: many, **opts)
        end

        # @see Serega::ClassMethods#to_struct
        def to_struct(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil, **opts) # :nodoc:
          new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
            .to_struct(object, context: context, many: many, **opts)
        end

        # @see Serega::ClassMethods#to_json
        def to_json(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil, **opts) # :nodoc:
          new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
            .to_json(object, context: context, many: many, **opts)
        end

        alias_method :to_h, :call # :nodoc:

        # Sets the root keys: one key for objects and lists, or separate `one:`
        # and `many:` keys
        #
        # ```ruby
        # root :users
        # root one: :user, many: :users
        # ```
        def root(root = nil, one: nil, many: nil)
          one ||= root
          many ||= root

          config.root = {one: one, many: many}
        end
      end

      # Root keys, `config.root`
      class RootConfig
        attr_reader :opts # :nodoc:

        #
        # Initializes RootConfig object
        #
        # @param opts [Hash] root options
        # @option opts [Symbol, String, nil] :one root for single-object serialization
        # @option opts [Symbol, String, nil] :many root for many-objects serialization
        #
        # @return [SeregaPlugins::Root::RootConfig] RootConfig object
        #
        def initialize(opts) # :nodoc:
          @opts = opts
        end

        # Root key of one object
        def one
          opts.fetch(:one)
        end

        # Root key of a list
        def many
          opts.fetch(:many)
        end

        # Sets #one
        def one=(value)
          opts[:one] = value
        end

        # Sets #many
        def many=(value)
          opts[:many] = value
        end
      end

      # Config methods the plugin adds to Serega::SeregaConfig
      module ConfigInstanceMethods
        # Root keys
        def root
          @plugin_configs[:root] ||= RootConfig.new(opts.fetch(:root))
        end

        # Builds the root config before freezing
        def freeze # :nodoc:
          root
          super
        end

        # Sets the root keys from a Hash with `:one` and `:many`
        def root=(value)
          root.one = value.fetch(:one)
          root.many = value.fetch(:many)
        end
      end

      #
      # Serega additional/patched instance methods
      #
      # The serialization methods take `**opts`, see ClassMethods. The
      # options reach `#serialize` as its `opts`, after CheckSerializeParams
      # validates them.
      #
      # @see Serega
      #
      module InstanceMethods # :nodoc:
        # @see Serega::InstanceMethods#call
        def call(object, context: nil, many: nil, **opts)
          serialize_to(:hash, object, context, many, checked_opts(opts))
        end

        # @see Serega::InstanceMethods#to_data
        def to_data(object, context: nil, many: nil, **opts)
          serialize_to(:data, object, context, many, checked_opts(opts))
        end

        # @see Serega::InstanceMethods#to_struct
        def to_struct(object, context: nil, many: nil, **opts)
          serialize_to(:struct, object, context, many, checked_opts(opts))
        end

        # @see Serega::InstanceMethods#to_json
        def to_json(object, context: nil, many: nil, **opts)
          JSON.generate(call(object, context: context, many: many, **opts))
        end

        alias_method :to_h, :call

        private

        def checked_opts(opts)
          return FROZEN_EMPTY_HASH if opts.empty?

          self.class::CheckSerializeParams.new(opts).validate
          opts
        end

        def serialize(object, opts, context, many, mode)
          result = super
          root = build_root(opts, many)
          result = {root => result} if root
          result
        end

        def build_root(opts, many)
          return opts[:root] if opts.key?(:root)

          root = self.class.config.root
          many ? root.many : root.one
        end
      end
    end

    register_plugin(Root.plugin_name, Root)
  end
end
