# frozen_string_literal: true

require "delegate"

class Serega
  #
  # Wraps the serialized object, so computed attribute values can be defined as
  # methods instead of `:value` callables.
  #
  # SeregaPresenter inherits from SimpleDelegator:
  # - All methods of the serialized object are available directly inside presenter methods.
  # - Methods not defined on SeregaPresenter are resolved via method_missing on the first call
  #   and then defined as real delegators, so subsequent calls skip method_missing entirely.
  # - The original object is accessible via __getobj__ (standard SimpleDelegator API).
  # - The serialization context is accessible via the private method __ctx__.
  #
  # The `presenter do ... end` block is evaluated inside the serializer's own
  # SeregaPresenter class, so multiple blocks accumulate.
  #
  # @example
  #   class UserSerializer < Serega
  #     attribute :name
  #     attribute :role
  #
  #     presenter do
  #       def name
  #         [first_name, last_name].compact.join(' ') # first_name/last_name delegated to object
  #       end
  #
  #       def role
  #         id == __ctx__[:current_user_id] ? :self : :other
  #       end
  #     end
  #   end
  #
  # @private
  class SeregaPresenter < SimpleDelegator
    # Method names of delegators defined with a compiled `def`
    PLAIN_METHOD_NAME = /\A[a-z_][a-zA-Z0-9_]*[?!]?\z/
    private_constant :PLAIN_METHOD_NAME

    #
    # Includes into each presenter class its own `Delegators` module.
    # Delegators to serialized object methods are defined there after the
    # first #method_missing hit. Presenter methods override them and can call
    # them via `super`.
    #
    # @param subclass [Class<SeregaPresenter>] New presenter class
    #
    # @return [void]
    #
    def self.inherited(subclass)
      super
      delegators = Module.new
      subclass.const_set(:Delegators, delegators)
      subclass.include(delegators)
    end

    #
    # Defines a method that delegates to the serialized object in the
    # presenter class `Delegators` module
    #
    # @param name [Symbol] Method name
    #
    # @return [void]
    #
    def self.define_delegator(name)
      delegators = self::Delegators

      if PLAIN_METHOD_NAME.match?(name)
        delegators.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
          def #{name}(...)
            __getobj__.#{name}(...)
          end
        RUBY
      else
        delegators.define_method(name) { |*args, **kwargs, &block| __getobj__.public_send(name, *args, **kwargs, &block) }
      end
    end

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
    # Creates delegator method for public methods of serialized object after
    # first #method_missing hit to improve performance of following serializations.
    #
    def method_missing(name, ...) # rubocop:disable Style/MissingRespondToMissing -- base SimpleDelegator class has this method
      result = super
      self.class.define_delegator(name) if __getobj__.respond_to?(name)
      result
    end
  end
end
