# frozen_string_literal: true

require "delegate"

class Serega
  # Wraps the object to serialize, so computed attribute values can be defined as
  # methods instead of `:value` callables.
  #
  # SeregaPresenter inherits from SimpleDelegator:
  # - All methods of the wrapped object are available directly inside presenter methods.
  # - Methods not defined on SeregaPresenter are resolved via method_missing on the first call
  #   and then defined as real delegators, so subsequent calls skip method_missing entirely.
  # - The original object is accessible via __getobj__ (standard SimpleDelegator API).
  # - The serialization context is accessible via the private method __ctx__.
  #
  # The `presenter do ... end` block is evaluated inside the serializer's own
  # SeregaPresenter class, so multiple blocks accumulate.
  #
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
  class SeregaPresenter < SimpleDelegator # :nodoc:
    # Method names of delegators defined with a compiled `def`
    PLAIN_METHOD_NAME = /\A[a-z_][a-zA-Z0-9_]*[?!]?\z/
    private_constant :PLAIN_METHOD_NAME

    #
    # Delegator to the method of the wrapped object with the name it is
    # called by. Delegators with other names are its aliases.
    #
    module CalleeDelegator # :nodoc:
      #
      # Calls the method of the wrapped object with the name of the alias
      #
      def __serega_delegate__(...)
        __getobj__.public_send(__callee__, ...)
      end
    end

    # Includes into each presenter class its own `Delegators` module.
    # Delegators to the methods of the wrapped object are defined there after the
    # first #method_missing hit. Presenter methods override them and can call
    # them via `super`.
    def self.inherited(subclass)
      super
      delegators = Module.new
      delegators.include(CalleeDelegator)
      subclass.const_set(:Delegators, delegators)
      subclass.include(delegators)
    end

    # Defines a method that delegates to the wrapped object in the
    # presenter class `Delegators` module
    def self.define_delegator(name)
      delegators = self::Delegators

      if PLAIN_METHOD_NAME.match?(name)
        delegators.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
          def #{name}(...)
            __getobj__.#{name}(...)
          end
        RUBY
      else
        delegators.alias_method(name, :__serega_delegate__)
      end
    end

    # Defines delegators for the method names that the presenter class does
    # not define itself, thus presenter methods stay in front of them
    def self.define_delegators(names)
      names.each do |name|
        define_delegator(name) unless method_defined?(name) || private_method_defined?(name)
      end
    end

    def initialize(object, ctx = nil)
      super(object)
      @__ctx__ = ctx
    end

    private

    attr_reader :__ctx__

    #
    # Delegates all missing methods to the wrapped object.
    #
    # Creates delegator method for public methods of the wrapped object after
    # first #method_missing hit to improve performance of following serializations.
    #
    def method_missing(name, ...) # rubocop:disable Style/MissingRespondToMissing -- base SimpleDelegator class has this method
      result = super
      self.class.define_delegator(name) if __getobj__.respond_to?(name)
      result
    end
  end
end
