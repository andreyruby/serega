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

## Decimals

Serega returns a `BigDecimal` as is, and `to_json` writes it with
`JSON.generate`. Without ActiveSupport this writes it as a String in
scientific notation: `"0.51501364e2"`. With ActiveSupport, as in Rails, it
writes `"51.501364"`. A formatter gives the same output in both cases.

```ruby
class PlaceSerializer < Serega
  # JSON numbers: value.to_f
  attribute :latitude, format: [:to_f]
  attribute :longitude, format: [:to_f]
end

PlaceSerializer.to_json(place)
# => "{\"latitude\":51.501364,\"longitude\":-0.14189}"
```

A Float keeps about 17 significant digits, thus `to_f` rounds longer decimals:
`BigDecimal("12345678901234567.89").to_f` is `1.2345678901234568e+16`. For a
String with every digit, use `format: [:to_s, "F"]`.

## `nil` values

A formatter formats `nil` too: a callable receives `nil`, and a method is
called on `nil`. With `allow_nil: true` a `nil` value stays `nil`.

```ruby
formatter :iso8601, [:iso8601, 3], allow_nil: true
attribute :rating, format: {use: [:round, 1], allow_nil: true}
```

A [`:default`](attributes.md#default) value is formatted too.
