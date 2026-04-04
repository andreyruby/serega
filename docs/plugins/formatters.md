# Plugin :formatters

Defines named value transformers and applies them to attributes via the `:format` option.

## When to use

- Dates, money amounts, or booleans need consistent formatting across multiple serializers.
- You want to name a formatting rule once and reuse it on many attributes.
- You need per-attribute inline formatting without defining a named formatter.

## Setup

```ruby
class AppSerializer < Serega
  plugin :formatters, formatters: {
    iso8601: ->(value) { value.iso8601 },
    on_off:  ->(value) { value ? "ON" : "OFF" }
  }
end
```

## Using a formatter

```ruby
attribute :created_at, format: :iso8601
attribute :is_active,  format: :on_off

# Inline proc
attribute :score, format: proc { |v| "#{v.round(2)}%" }

# Callable class
attribute :score, format: ScoreFormatter
```

## Formatter parameters

A formatter callable can accept up to two positional parameters, or one positional parameter plus a `:ctx` keyword:

```ruby
->(value)               # value only
->(value, context)      # value and serialization context
->(value, ctx:)         # value and context as keyword :ctx
```

Passing more or fewer parameters raises a validation error when the attribute is defined.

## Adding formatters in subclasses

Use `config.formatters.add` to register additional formatters without re-loading the plugin:

```ruby
class UserSerializer < AppSerializer
  config.formatters.add(
    percent: ->(v) { "#{v.round(2)}%" }
  )

  attribute :score, format: :percent
end
```

## Runnable example

`examples/formatters.rb`

---

**Next:** [if](if.md)
