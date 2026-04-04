# Plugin :if

Conditionally includes or excludes attributes from the serialized output.

## When to use

- Certain fields should only appear for authorized callers (e.g. hide `email` unless the viewer owns the record).
- You want to skip `nil` or blank values without writing a formatter.
- Visibility depends on runtime context passed to the serializer.

## Setup

```ruby
class AppSerializer < Serega
  plugin :if
end
```

## Four options

### `:if`

Evaluated before the attribute value is computed. Receives `(object, context)`. Include the attribute when the callable returns truthy.

```ruby
attribute :email, if: :active?                                   # calls object.active?
attribute :email, if: proc { |user| user.active? }
attribute :email, if: proc { |user, ctx| user == ctx[:current_user] }
attribute :email, if: CustomPolicy.method(:view_email?)
```

### `:unless`

Inverse of `:if`. Exclude the attribute when the callable returns truthy.

```ruby
attribute :email, unless: :hidden?
attribute :email, unless: proc { |user| user.hidden? }
attribute :email, unless: proc { |user, ctx| ctx[:hide_emails] }
```

### `:if_value`

Evaluated after the attribute value is computed. Receives `(value, context)`. Include the attribute when the callable returns truthy.

Cannot be used with `:serializer` — nested serializers do not produce a scalar value at this point. Use `:if` instead.

```ruby
attribute :email, if_value: :present?                            # calls value.present?
attribute :email, if_value: proc { |email| email.present? }
attribute :email, if_value: proc { |email, ctx| ctx[:show_emails] }
```

### `:unless_value`

Inverse of `:if_value`. Exclude the attribute when the callable returns truthy.

```ruby
attribute :email, unless_value: :blank?
attribute :email, unless_value: proc { |email| email.blank? }
attribute :email, unless_value: proc { |email, ctx| ctx[:hide_emails] }
```

## Accepted callable forms

Each option accepts:

- A `Symbol` — name of a method called on the object (for `:if`/`:unless`) or on the value (for `:if_value`/`:unless_value`).
- A `Proc` — may receive:
  - `()` — no parameters
  - `(object_or_value)` — one positional argument
  - `(object_or_value, context)` — two positional arguments
  - `(object_or_value, ctx:)` — one positional plus `:ctx` keyword
- Any callable object (responds to `#call`).

## Difference from `:hide`

`:hide` is a static flag set at class definition time and can be overridden by `only:`/`with:` modifiers. The `:if` family is evaluated at serialization time and cannot be overridden by field selectors.

---

**Next:** [root](root.md)
