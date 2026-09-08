# frozen_string_literal: true

require "delegate"
require "forwardable"

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

    extend Forwardable
  end
end
