# Plugin :depth_limit

Raises `Serega::DepthLimitError` when the serialization nesting depth exceeds a configured limit.

## When to use

- Your API lets callers specify nested fields via `with:` and you need to cap how deep they can go.
- You want to guard against accidental cyclic serialization (e.g. user → posts → user → ...).
- You want errors to surface early, before any database queries run.

## When the check runs

The depth is checked at plan construction time — when `SomeSerializer.new(...)` is called or when a class-level serialization method is used. This happens before any data is fetched, so you can instantiate the serializer at the start of a request to fail fast.

## Setup

```ruby
class AppSerializer < Serega
  plugin :depth_limit, limit: 10
end

class UserSerializer < AppSerializer
  config.depth_limit.limit = 5   # override for this serializer only
end
```

The `:limit` option is required when loading the plugin. There is no default.

## Error details

`Serega::DepthLimitError` is a subclass of `SeregaError`. It provides a `#details` method that returns a string describing the chain of fields that exceeded the limit:

```ruby
rescue Serega::DepthLimitError => e
  puts e.message  # "Depth limit was exceeded"
  puts e.details  # "UserSerializer (depth limit: 5) -> posts -> comments -> author"
end
```

## Config reference

| Method | Description |
|---|---|
| `config.depth_limit.limit` | Returns the current limit (Integer). |
| `config.depth_limit.limit = n` | Sets the limit. Must be an Integer. |

---

**Next:** [string_modifiers](string_modifiers.md)
