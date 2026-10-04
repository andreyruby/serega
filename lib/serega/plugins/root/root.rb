# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin :root
    #
    # Adds a root key to serialized data.
    #
    # Accepts options:
    #  - :root - specifies root for all responses
    #  - :root_one - specifies root for single object serialization only
    #  - :root_many - specifies root for multiple objects serialization only
    #
    # Adds additional config options:
    #   - config.root.one
    #   - config.root.many
    #   - config.root.one=
    #   - config.root.many=
    #
    # Default root is `:data`.
    #
    # Root can also be changed per serialization, or removed entirely by
    # providing `root: nil` (per serialization it can still be added back).
    #
    # @example Define plugin
    #   class UserSerializer < Serega
    #     plugin :root # default root is :data
    #   end
    #
    #   class UserSerializer < Serega
    #     plugin :root, root: :users
    #   end
    #
    #   class UserSerializer < Serega
    #     plugin :root, root_one: :user, root_many: :people
    #   end
    #
    #   class UserSerializer < Serega
    #     plugin :root, root: nil # no root by default
    #   end
    #
    # @example Change root per serialization:
    #   class UserSerializer < Serega
    #     plugin :root
    #   end
    #
    #   UserSerializer.to_h(nil)              # => {:data=>nil}
    #   UserSerializer.to_h(nil, root: :user) # => {:user=>nil}
    #   UserSerializer.to_h(nil, root: nil)   # => nil
    #
    module Root
      # @return [Symbol] Default response root key
      ROOT_DEFAULT = :data

      # @return [Symbol] Plugin name
      # @private
      def self.plugin_name
        :root
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
      # @private
      def self.load_plugin(serializer_class, **_opts)
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
      # @private
      def self.after_load_plugin(serializer_class, **opts)
        config = serializer_class.config
        default = opts.fetch(:root, ROOT_DEFAULT)
        one = opts.fetch(:root_one, default)
        many = opts.fetch(:root_many, default)
        config.opts[:root] = {}
        config.root = {one: one, many: many}

        config.serialize_keys << :root
      end

      #
      # Serega additional/patched class methods
      #
      # @see Serega
      #
      module ClassMethods
        #
        # Configures response root key
        #
        # @param root [String, Symbol, nil] Specifies common root keyword used when serializing one or multiple objects
        # @param one [String, Symbol, nil] Specifies root keyword used when serializing one object
        # @param many [String, Symbol, nil] Specifies root keyword used when serializing multiple objects
        #
        # @return [Hash] Configured root names
        #
        def root(root = nil, one: nil, many: nil)
          one ||= root
          many ||= root

          config.root = {one: one, many: many}
        end
      end

      # Root config object
      class RootConfig
        attr_reader :opts

        #
        # Initializes RootConfig object
        #
        # @param opts [Hash] root options
        # @option opts [Symbol, String, nil] :one root for single-object serialization
        # @option opts [Symbol, String, nil] :many root for many-objects serialization
        #
        # @return [SeregaPlugins::Root::RootConfig] RootConfig object
        #
        def initialize(opts)
          @opts = opts
        end

        # @return [Symbol, String, nil] defined root for single-object serialization
        def one
          opts.fetch(:one)
        end

        # @return [Symbol, String, nil] defined root for many-objects serialization
        def many
          opts.fetch(:many)
        end

        #
        # Set root for single-object serialization
        #
        # @param value [Symbol, String, nil] root key
        #
        # @return [Symbol, String, nil] root key for single-object serialization
        def one=(value)
          opts[:one] = value
        end

        #
        # Set root for multiple-object serialization
        #
        # @param value [Symbol, String, nil] root key
        #
        # @return [Symbol, String, nil] root key for multiple-object serialization
        def many=(value)
          opts[:many] = value
        end
      end

      #
      # Serega::SeregaConfig additional/patched class methods
      #
      # @see Serega::SeregaConfig
      #
      module ConfigInstanceMethods
        # @return [Serega::SeregaPlugins::Root::RootConfig] current root config
        def root
          @root ||= RootConfig.new(opts.fetch(:root))
        end

        # Set root for one-object and many-objects serialization types
        #
        # @param value [Hash]
        # @option value [Symbol, String, nil] :one Root for one-object serialization type
        # @option value [Symbol, String, nil] :many Root for many-objects serialization type
        #
        # @return [void]
        def root=(value)
          root.one = value.fetch(:one)
          root.many = value.fetch(:many)
        end
      end

      #
      # Serega additional/patched instance methods
      #
      # @see Serega
      #
      # @private
      module InstanceMethods
        #
        # Serializes provided object to a tree of Ruby Data objects.
        # When a root key is configured, returns a Hash with Data objects under
        # the root key, plus any metadata keys.
        #
        # @param object [Object] Serialized object
        # @param opts [Hash, nil] Serializing options (`:root`, `:many`, `:context`, etc.)
        #
        # @return [Hash, Data, Array<Data>, nil] Serialization result
        #
        def to_data(object, opts = nil)
          opts = normalize_serialization_opts(opts)
          object = prepare_objects(object, opts[:context])
          opts = prepare_initial_serialization_opts(object, opts, :data)
          result = serialize(object, opts)
          root = build_root(object, opts)
          return self.class::SeregaDataBuilder.call(self, result) unless root

          result[root] = self.class::SeregaDataBuilder.call(self, result[root])
          result
        end

        private

        def serialize(object, opts)
          result = super
          root = build_root(object, opts)
          result = {root => result} if root
          result
        end

        def build_root(object, opts)
          return opts[:root] if opts.key?(:root)

          root = self.class.config.root
          (opts.fetch(:many) { SeregaUtils::CollectionDetector.call(object) }) ? root.many : root.one
        end
      end
    end

    register_plugin(Root.plugin_name, Root)
  end
end
