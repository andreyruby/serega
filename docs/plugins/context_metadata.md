# Plugin :context_metadata

Lets callers pass metadata at serialization time; that metadata is merged into the response hash.

**Depends on:** the `:root` plugin must be loaded before `:context_metadata`.

## When to use

- Per-request metadata (pagination cursors, request IDs, latency) needs to be included in responses.
- The metadata is not known at class-definition time, so `:metadata` is not an option.
- You want a single conventional key (default `:meta`) for callers to attach arbitrary data.

## Setup

```ruby
class UserSerializer < Serega
  plugin :root
  plugin :context_metadata, context_metadata_key: :meta
end

UserSerializer.to_h(user, meta: { version: "1.0.1" })
# => { data: { ... }, version: "1.0.1" }
```

The value passed under the context metadata key must be a `Hash`. Its contents are deep-merged into the response.

## Plugin option

| Option | Description |
|---|---|
| `:context_metadata_key` | The key callers use in the serialization options hash. Default: `:meta`. |

## Changing the key in subclasses

```ruby
config.context_metadata.key = :my_meta
```

After this change, callers pass `my_meta: { ... }` instead of `meta: { ... }`.

---

**Next:** [camel_case](camel_case.md)
