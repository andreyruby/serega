# Formatters

Formatters format dates, money and other values the same way in every
serializer. Define named formatters in a base serializer and use them with the
`:format` attribute option.

```ruby
class AppSerializer < Serega
  formatter :iso8601, [:iso8601, 3], allow_nil: true
  formatter :money, ->(cents, ctx) { "#{(cents / 100.0).round(2)} #{ctx[:currency]}" }
end

class OrderSerializer < AppSerializer
  attribute :created_at, format: :iso8601
  attribute :total_cents, format: :money
end

OrderSerializer.to_h(order, context: {currency: "EUR"})
# => {created_at: "2026-10-18T12:30:15.000Z", total_cents: "19.99 EUR"}
```

Child serializers get the formatters of their parents.

## Formatter kinds

```ruby
class AppSerializer < Serega
  # A method name: value.to_s
  formatter :string, :to_s

  # A method name with arguments: value.iso8601(3)
  formatter :iso8601, [:iso8601, 3]

  # A callable with the value
  formatter :yes_no, ->(value) { value ? "yes" : "no" }

  # A callable with the value and the context, as a second parameter or the :ctx keyword
  formatter :money, ->(cents, ctx) { "#{cents / 100.0} #{ctx[:currency]}" }
  formatter :price, ->(cents, ctx:) { "#{cents / 100.0} #{ctx[:currency]}" }

  # A block
  formatter(:upcase) { |value| value.upcase }
end
```

A method formatter is called directly in the generated serialization code,
which makes it the fastest kind.

## Formatters without a name

`:format` also accepts a formatter directly. A Symbol is always a formatter
name, so a method name alone needs a named formatter.

```ruby
attribute :rating, format: [:round, 1]
attribute :email, format: ->(email) { email.downcase }
attribute :nickname, format: {use: :upcase, allow_nil: true}
```

## `nil` values

A formatter formats `nil` too: a callable receives `nil`, and a method is
called on `nil`. With `allow_nil: true` a `nil` value stays `nil`.

```ruby
formatter :iso8601, [:iso8601, 3], allow_nil: true
attribute :rating, format: {use: [:round, 1], allow_nil: true}
```

A [`:default`](attributes.md#default) value is formatted too.
