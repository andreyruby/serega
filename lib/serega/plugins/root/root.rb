# frozen_string_literal: true

class Serega
  module SeregaPlugins
    #
    # Plugin :root
    #
    # Allows to add root key to your serialized data
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
    #   - config.root_many=
    #
    # Default root is `:data`.
    #
    # Root also can be changed per serialization.
    #
    # Also root can be removed for all responses by providing `root: nil`. In this case no root will be added to response, but
    # you still can to add it per serialization
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
      def self.load_plugin(serializer_class, **_opts)
        serializer_class.extend(ClassMethods)
        serializer_class.include(InstanceMethods)
        serializer_class::SeregaConfig.include(ConfigInstanceMethods)
        serializer_class::SeregaDataBuilder.extend(DataBuilderClassMethods)
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
      module InstanceMethods
        #
        # Serializes provided object to a tree of Ruby Data objects.
        # When a root key is configured, the result is wrapped in an outer Data object
        # whose members include the root key plus any metadata keys.
        #
        # @param object [Object] Serialized object
        # @param opts [Hash, nil] Serializing options (`:root`, `:many`, `:context`, etc.)
        #
        # @return [Data, Array<Data>, nil] Serialization result as Data object(s)
        #
        def to_data(object, opts = nil)
          opts = prepare_initial_serialization_opts(object, opts)
          serialized_data = serialize(object, opts)
          self.class::SeregaDataBuilder.call(self, serialized_data, opts)
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

      #
      # SeregaDataBuilder additional/patched class methods
      #
      # Overrides `call` to handle the root key: the serialized result is
      # unwrapped from the root key, converted to a Data tree by the base
      # implementation, and then re-wrapped together with any metadata keys
      # in an outer Data object. Metadata values (arbitrary hashes/arrays)
      # are recursively converted to Data objects via `deep_hash_to_data`.
      #
      # When the root key is `nil` (disabled), delegates directly to the base.
      #
      # @see Serega::SeregaDataBuilder
      #
      module DataBuilderClassMethods
        #
        # @param serializer [Serega] Serializer instance carrying the plan
        # @param serialized_result [Hash, Array, nil] Full serialized output (possibly wrapped under root key)
        # @param serialization_opts [Hash] Serialization options used to determine the root key
        #
        # @return [Data, Array<Data>, nil] Serialization result as Data object(s)
        #
        def call(serializer, serialized_result, serialization_opts)
          root_key = resolve_root_key(serializer, serialization_opts)
          return super(serializer, serialized_result) unless root_key

          root_data = super(serializer, serialized_result.fetch(root_key))
          build_data_objects(serialized_result, root_key, root_data)
        end

        private

        def resolve_root_key(serializer, serialization_opts)
          if serialization_opts.key?(:root)
            serialization_opts[:root]
          else
            config_root = serializer.class.config.root
            serialization_opts[:many] ? config_root.many : config_root.one
          end
        end

        def build_data_objects(serialized_result, root_key, root_data)
          converted_hash =
            serialized_result.to_h do |key, val|
              value = (key == root_key) ? root_data : deep_hash_to_data(val)
              [key, value]
            end

          Data.define(*converted_hash.keys).new(**converted_hash)
        end

        def deep_hash_to_data(value)
          case value
          when Hash
            converted = value.transform_values { |nested| deep_hash_to_data(nested) }
            Data.define(*value.keys).new(**converted)
          when Array
            value.map { |item| deep_hash_to_data(item) }
          else
            value
          end
        end
      end
    end

    register_plugin(Root.plugin_name, Root)
  end
end
