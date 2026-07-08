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
      end

      #
      # Serega additional/patched class methods
      #
      # @see Serega
      #
      module ClassMethods
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
        private

        #
        # Replaces serialized object with Presenter.new(object, ctx)
        #
        def serialize_object(object)
          object = self.class.serializer_class::Presenter.new(object, context)
          super
        end
      end
    end

    register_plugin(Presenter.plugin_name, Presenter)
  end
end
