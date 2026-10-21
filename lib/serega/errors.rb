# frozen_string_literal: true

class Serega
  #
  # Base exception class
  #
  class SeregaError < StandardError; end

  # Raised when serializer is initiated using not existing attribute
  #
  # @example
  #   Serega.new(only: 'FOO')
  #   # => Attribute 'FOO' not exists (Serega::AttributeNotExist)
  class AttributeNotExist < SeregaError
    attr_reader :serializer, :attributes

    def initialize(message = nil, serializer = nil, attributes = nil)
      super(message)
      @serializer = serializer
      @attributes = attributes
    end
  end

  # Raised when a serialization plan nests deeper than `config.depth_limit`
  # of the root serializer
  #
  # @example
  #   UserSerializer.new(with: {friends: :friends})
  #   # => Depth limit was exceeded (Serega::DepthLimitError)
  class DepthLimitError < SeregaError
    # @return [String] Path of the plan that exceeds the limit
    attr_reader :details

    def initialize(message = nil, details = nil)
      super(message)
      @details = details
    end
  end
end
