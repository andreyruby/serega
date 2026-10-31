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
      # Default response root key
      ROOT_DEFAULT = :data # :nodoc:

      # Adds the plugin to the serializer
      def self.apply(serializer_class, **opts) # :nodoc:
        SeregaValidations::Utils::CheckAllowedKeys.call(opts, %i[root root_one root_many], "plugin :root")

        serializer_class.extend(ClassMethods)
        serializer_class.include(InstanceMethods)
        serializer_class::SeregaConfig.include(ConfigInstanceMethods)

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
        def call(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil, **opts) # :nodoc:
          new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
            .to_h(object, context: context, many: many, **opts)
        end

        def to_data(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil, **opts) # :nodoc:
          new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
            .to_data(object, context: context, many: many, **opts)
        end

        def to_struct(object, only: nil, with: nil, except: nil, check_initiate_params: nil, context: nil, many: nil, **opts) # :nodoc:
          new(only: only, with: with, except: except, check_initiate_params: check_initiate_params)
            .to_struct(object, context: context, many: many, **opts)
        end

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

        # Initializes RootConfig object
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

      # Serega additional/patched instance methods
      #
      # The serialization methods take `**opts`, see ClassMethods. The
      # options reach `#serialize` as its `opts`, after #checked_opts
      # validates them.
      module InstanceMethods # :nodoc:
        def call(object, context: nil, many: nil, **opts)
          serialize_to(:hash, object, context, many, checked_opts(opts))
        end

        def to_data(object, context: nil, many: nil, **opts)
          serialize_to(:data, object, context, many, checked_opts(opts))
        end

        def to_struct(object, context: nil, many: nil, **opts)
          serialize_to(:struct, object, context, many, checked_opts(opts))
        end

        def to_json(object, context: nil, many: nil, **opts)
          JSON.generate(call(object, context: context, many: many, **opts))
        end

        alias_method :to_h, :call

        private

        # Patched in:
        # - plugin :context_metadata (checks the context metadata is a Hash)
        def checked_opts(opts)
          return FROZEN_EMPTY_HASH if opts.empty?

          SeregaValidations::Utils::CheckAllowedKeys.call(opts, self.class.config.serialize_keys, :serialize)
          opts
        end

        def serialize(object, opts, context, many, mode)
          result = super
          root = build_root(opts, many)
          result = {root => result} if root
          result
        end

        # Root key of the serialization, nil without a root. Read by the
        # plugins :metadata and :context_metadata, which add their data only
        # under a root.
        def build_root(opts, many)
          return opts[:root] if opts.key?(:root)

          root = self.class.config.root
          many ? root.many : root.one
        end
      end
    end
  end
end
