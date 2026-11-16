# Formatters

Formatters format dates, money and other values the same way in every
serializer. Named formatters, defined for example in a base serializer, are
used with the `:format` attribute option.

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

Child serializers get the formatters of their parents. Define a formatter
before the attributes that use it: `format: :money` with no `:money`
formatter defined yet raises `Serega::SeregaError`.

A formatter also receives `nil`: `[:iso8601, 3]` on a missing time raises
`NoMethodError`. Add `allow_nil: true` to a formatter of a value that can be
`nil`, see [Formatting `nil` values](#formatting-nil-values).

## Table of Contents

<!-- toc -->

- [Formatter kinds](#formatter-kinds)
- [Formatting `nil` values](#formatting-nil-values)
- [Formatters without a name](#formatters-without-a-name)
- [Common formatters](#common-formatters)
   - [Times for JavaScript clients (`:iso8601`)](#times-for-javascript-clients-iso8601)
   - [Dates (`:date`)](#dates-date)
   - [Decimals as JSON numbers (`:float`)](#decimals-as-json-numbers-float)
   - [Rounding (`:round2`)](#rounding-round2)
   - [Percents (`:percent`)](#percents-percent)
   - [Blank strings as `nil` (`:presence`)](#blank-strings-as-nil-presence)
   - [API type names (`:type`)](#api-type-names-type)
   - [Money (`:money`)](#money-money)
- [Decimals in JSON](#decimals-in-json)

<!-- tocstop -->

## Formatter kinds

```ruby
class AppSerializer < Serega
  # A method name: value.to_s
  formatter :string, :to_s

  # A method name with arguments: value.iso8601(3)
  formatter :iso8601, [:iso8601, 3]

  # An operator is a method too: value * 100
  formatter :percent, [:*, 100]

  # A callable with the value
  formatter :yes_no, ->(value) { value ? "yes" : "no" }

  # A callable with the value and the context, as a second parameter or the :ctx keyword
  formatter :money, ->(cents, ctx) { "#{cents / 100.0} #{ctx[:currency]}" }
  formatter :price, ->(cents, ctx:) { "#{cents / 100.0} #{ctx[:currency]}" }

  # A block
  formatter(:upcase) { |value| value.upcase }
end
```

A Symbol or an Array in a formatter is a plain Ruby method of the value, with
its arguments: `:to_s` calls `value.to_s`, and `[:iso8601, 3]` calls
`Time#iso8601(3)`. Serega adds no formatting methods of its own, so any method
of the value works, from Ruby, ActiveSupport or your own classes.

A method formatter is called directly in the generated serialization code,
which makes it the fastest kind.

## Formatting `nil` values

A formatter formats `nil` too: a callable receives `nil`, and a method is
called on `nil`. With `allow_nil: true` a `nil` value stays `nil`.

```ruby
formatter :iso8601, [:iso8601, 3], allow_nil: true
attribute :rating, format: {use: [:round, 1], allow_nil: true}
```

A [`:default`](attributes.md#default) value is formatted too.

`:if_value` and `:unless_value` check the formatted value. Without
`allow_nil: true`, a formatter that turns `nil` into `0.0` keeps the
attribute that `unless_value: :nil?` should skip:

```ruby
attribute :rating, format: ->(rating) { rating.to_f.round(1) }, unless_value: :nil?
# => {rating: 0.0} for a nil rating

attribute :rating, format: {use: ->(rating) { rating.to_f.round(1) }, allow_nil: true}, unless_value: :nil?
# => {} for a nil rating
```

## Formatters without a name

`:format` also accepts a formatter directly. A Symbol is always a formatter
name, so a method name alone needs a named formatter.

```ruby
attribute :rating, format: [:round, 1]
attribute :email, format: ->(email) { email.downcase }
attribute :nickname, format: {use: :upcase, allow_nil: true}
```

`allow_nil:` needs the Hash form, with the formatter under `:use`.

## Common formatters

Examples of formatters that many APIs use. Copy the ones you need, for
example into a base serializer, and change them as you like. The names, such
as `:round2`, are yours to choose. The methods they call are Ruby's:
`Time#iso8601`, `Date#iso8601`, `BigDecimal#to_f`, `Float#round` and
ActiveSupport's `Object#presence`.

### Times for JavaScript clients (`:iso8601`)

JavaScript dates resolve to milliseconds, so three fraction digits are enough.

```ruby
formatter :iso8601, [:iso8601, 3], allow_nil: true

attribute :created_at, format: :iso8601
# Time.utc(2026, 11, 16, 10, 30, 15.123456) => "2026-11-16T10:30:15.123Z"
# nil => nil
```

### Dates (`:date`)

```ruby
formatter :date, :iso8601, allow_nil: true

attribute :birthday, format: :date
# Date.new(2026, 11, 16) => "2026-11-16"
```

### Decimals as JSON numbers (`:float`)

Decimal columns return a `BigDecimal`, which JSON writes as a String, see
[Decimals in JSON](#decimals-in-json).

```ruby
formatter :float, :to_f, allow_nil: true

attribute :latitude, format: :float
# BigDecimal("51.501364") => 51.501364
# nil => nil
```

### Rounding (`:round2`)

```ruby
formatter :round2, [:round, 2]

attribute :ratio, format: :round2
# 12.345 => 12.35
```

### Percents (`:percent`)

```ruby
formatter :percent, ->(fraction) { (fraction * 100).round(2) }

attribute :conversion, format: :percent
# 0.125 => 12.5
```

### Blank strings as `nil` (`:presence`)

`Object#presence` comes from ActiveSupport.

```ruby
formatter :presence, :presence

attribute :bio, format: :presence
# "" => nil
# "Freedonia" => "Freedonia"
```

### API type names (`:type`)

Clients that store records by type and id need a type in every record. A
constant attribute holds the model, and the formatter names its type. The
formatter takes a class or a class name, so it also names the type of a
polymorphic `*_type` column.

```ruby
TYPES = {"User" => "users", "Post" => "posts"}.freeze
formatter :type, ->(model) { TYPES.fetch(model.to_s) }

attribute :type, const: User, format: :type
# User => "users"

attribute :commentable_type, format: :type
# "Post" => "posts"
```

`TYPES.fetch` raises `KeyError` for a model without a type, so a new model
can't send a wrong one. The Hash keeps API type names apart from class names:
renaming a model doesn't change the API, and `TYPES.invert` turns a type from
a request back into a class name.

### Money (`:money`)

Money in cents, without trailing zeros. A formatter that depends on the
locale or the currency fits a callable class:
`formatter :money, MoneyFormatter.new`.

```ruby
formatter :money, ->(cents) { format("$%.2f", cents / 100.0).delete_suffix(".00") }

attribute :price_cents, format: :money
# 1999 => "$19.99"
# 2000 => "$20"
```

## Decimals in JSON

Serega returns a `BigDecimal` as is, and `to_json` writes it with
`JSON.generate`. Without ActiveSupport this writes it as a String in
scientific notation: `"0.51501364e2"`. With ActiveSupport, as in Rails, it
writes `"51.501364"`. A formatter gives the same output in both cases.

```ruby
class PlaceSerializer < Serega
  attribute :latitude
  attribute :longitude
end

PlaceSerializer.to_json(place)
# => "{\"latitude\":\"0.51501364e2\",\"longitude\":\"-0.14189e0\"}" without ActiveSupport
# => "{\"latitude\":\"51.501364\",\"longitude\":\"-0.14189\"}" with ActiveSupport
```

With a formatter, the decimals are JSON numbers:

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
