# frozen_string_literal: true

class Serega
  # Raised on invalid definitions and options, and on changes of a locked
  # serializer. Parent class of the other Serega errors.
  #
  # See [Errors](https://github.com/andreyruby/serega/blob/master/docs/errors.md).
  class SeregaError < StandardError; end

  # Raised when `only:`, `except:` or `with:` names an unknown field
  #
  # ```ruby
  # UserSerializer.to_h(user, only: [:nickname, {friends: :age}])
  # # => Serega::AttributeNotExist: Not existing attributes: nickname, friends(age)
  # ```
  #
  # See [Unknown fields](https://github.com/andreyruby/serega/blob/master/docs/selecting-fields.md#unknown-fields).
  class AttributeNotExist < SeregaError
    # Serializer that has no such fields
    attr_reader :serializer

    # Unknown fields, for example `["nickname", "friends(age)"]`
    attr_reader :attributes

    def initialize(message = nil, serializer = nil, attributes = nil) # :nodoc:
      super(message)
      @serializer = serializer
      @attributes = attributes
    end
  end

  # Raised when fields nest deeper than `config.depth_limit` of the
  # serializer that starts the serialization
  #
  # ```ruby
  # UserSerializer.to_h(user, with: {friends: :friends})
  # # => Serega::DepthLimitError: Depth limit was exceeded
  # ```
  #
  # See [Depth limit](https://github.com/andreyruby/serega/blob/master/docs/configuration.md#depth-limit).
  class DepthLimitError < SeregaError
    # Path that exceeds the limit, for example
    # `UserSerializer (depth limit: 2) -> friends -> friends`
    attr_reader :details

    def initialize(message = nil, details = nil) # :nodoc:
      super(message)
      @details = details
    end
  end
end
