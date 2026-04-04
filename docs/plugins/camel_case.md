# Plugin :camel_case

Transforms snake_case attribute names to camelCase keys in the serialized output.

## When to use

- Your API is consumed by JavaScript clients that expect camelCase keys.
- You want automatic transformation rather than specifying `key:` on every attribute.
- Only some attributes should be excluded from transformation.

## Setup

```ruby
class AppSerializer < Serega
  plugin :camel_case
end

class UserSerializer < AppSerializer
  attribute :first_name    # key becomes :firstName
  attribute :last_name     # key becomes :lastName

  attribute :full_name, camel_case: false,  # opt-out: key stays :full_name
    value: proc { |u| [u.first_name, u.last_name].join(" ") }
end
```

The default transformation replaces `_x` with the uppercase letter using a simple regex. It does not require ActiveSupport.

## Custom transformation

Provide any callable that takes one argument (the attribute name as a mutable String) and returns the transformed name:

```ruby
class AppSerializer < Serega
  plugin :camel_case, transform: ->(name) { name.camelize }
end
```

The transform callable must accept exactly one positional parameter.

## Selecting fields with camelCase names

When using `only:`, `except:`, or `with:` modifiers, use the transformed (camelCase) names:

```ruby
UserSerializer.new(only: %i[firstName lastName]).to_h(user)
```

## Scope

This plugin transforms attribute output keys only. Root keys, metadata keys, and context_metadata keys are not affected.

---

**Next:** [presenter](presenter.md)
