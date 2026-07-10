# frozen_string_literal: true

require "delegate"
require "forwardable"

class Serega
  module SeregaPlugins
    #
    # Plugin :presenter — moves computed attribute logic into a dedicated Presenter class.
    #
    # Presenter inherits from SimpleDelegator:
    # - All methods of the serialized object are available directly inside presenter methods.
    # - Methods not defined on Presenter are resolved via method_missing on the first call
    #   and then defined as real delegators, so subsequent calls skip method_missing entirely.
    # - The original object is accessible via __getobj__ (standard SimpleDelegator API).
    # - The serialization context is accessible via the private method __ctx__.
    #
    # Objects are wrapped in the Presenter only when the serializer's Presenter
    # class (or an inherited one) was actually extended with custom methods —
    # a bare `plugin :presenter` adds no wrapping overhead. The check is
    # denormalized: `SerializerClass.custom_presenter?` is asked once per
    # object serializer and the result is reused for the whole level.
    #
    #   class UserSerializer < Serega
    #     plugin :presenter
    #
    #     attribute :name
    #     attribute :role
    #
    #     class Presenter
    #       def name
    #         [first_name, last_name].compact.join(' ') # first_name/last_name delegated to object
    #       end
    #
    #       def role
    #         id == __ctx__[:current_user_id] ? :self : :other
    #       end
    #     end
    #   end
    module Presenter
      # @return [Symbol] Plugin name
      def self.plugin_name
        :presenter
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
        serializer_class::SeregaObjectSerializer.include(SeregaObjectSerializerInstanceMethods)
      end

      #
      # Runs callbacks after plugin was attached
      #
      # @param serializer_class [Class<Serega>] Current serializer class
      # @param _opts [Hash] Plugin options
      #
      # @return [void]
      #
      def self.after_load_plugin(serializer_class, **_opts)
        presenter_class = Class.new(Presenter)
        presenter_class.serializer_class = serializer_class
        serializer_class.const_set(:Presenter, presenter_class)

        # The presenter's unwrap method returns the serialized object itself,
        # not an association — it must never be auto-preloaded.
        config = serializer_class.config
        config.auto_preload_excluded_methods = config.auto_preload_excluded_methods | [:__getobj__]
      end

      # Presenter class
      class Presenter < SimpleDelegator
        # Presenter instance methods
        module InstanceMethods
          #
          # @param object [Object] Serialized object to wrap
          # @param ctx [Hash, nil] Serialization context
          #
          def initialize(object, ctx = nil)
            super(object)
            @__ctx__ = ctx
          end

          private

          attr_reader :__ctx__

          #
          # Delegates all missing methods to serialized object.
          #
          # Creates delegator method after first #method_missing hit to improve
          # performance of following serializations.
          #
          def method_missing(name, *_args, &_block) # rubocop:disable Style/MissingRespondToMissing -- base SimpleDelegator class has this method
            super.tap do
              self.class.def_delegator :__getobj__, name
            end
          end
        end

        extend SeregaHelpers::SerializerClassHelper
        extend Forwardable
        include InstanceMethods

        # Tracks whether user code was added to the Presenter class.
        #
        # These singleton methods are defined after the base class body above,
        # so the plugin's own includes do not mark the base class as modified.
        # Lazy delegators defined by #method_missing do mark the class, but
        # they can appear only on presenters that are already wrapping.
        class << self
          #
          # Checks if this Presenter class (or an inherited one) was extended
          # with custom user code and therefore objects must be wrapped
          #
          # @return [Boolean] whether custom presenter methods were defined
          #
          def modified?
            return true if defined?(@modified)
            return false if equal?(Presenter) # the plugin's base class — the walk stops here

            superclass.modified?
          end

          def include(*modules)
            @modified = true
            super
          end

          def prepend(*modules)
            @modified = true
            super
          end

          private

          def method_added(name)
            @modified = true
            super
          end
        end
      end

      #
      # Serega additional/patched class methods
      #
      # @see Serega
      #
      module ClassMethods
        #
        # Checks if the serializer's Presenter class (or an inherited one) was
        # extended with custom user code. When it was not, serialized objects
        # are not wrapped in the Presenter at all.
        #
        # @return [Boolean] whether custom presenter methods were defined
        #
        def custom_presenter?
          self::Presenter.modified?
        end

        private

        def inherited(subclass)
          super

          presenter_class = Class.new(self::Presenter)
          presenter_class.serializer_class = subclass
          subclass.const_set(:Presenter, presenter_class)
        end
      end

      #
      # SeregaObjectSerializer additional/patched class methods
      #
      # @see Serega::SeregaObjectSerializer
      #
      module SeregaObjectSerializerInstanceMethods
        # The custom-presenter check is made once per object serializer here
        # and its result is reused for every enqueued chunk of the level.
        def initialize(**opts)
          super
          @wrap_in_presenter = self.class.serializer_class.custom_presenter?
        end

        private

        #
        # Wraps each serialized object in Presenter.new(object, ctx) before it is
        # enqueued, so the whole level — value resolution and batch loaders alike —
        # sees presenters. Objects are not wrapped when the Presenter class has
        # no custom methods — such wrapping would only add overhead and break
        # class checks (object.is_a?, Hash === object) without changing anything.
        #
        def enqueue(objects)
          return super unless @wrap_in_presenter

          presenter = self.class.serializer_class::Presenter
          presenters = objects.map { |object| presenter.new(object, context) }
          super(presenters)
        end
      end
    end

    register_plugin(Presenter.plugin_name, Presenter)
  end
end
