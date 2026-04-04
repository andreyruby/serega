# Plugin :metadata

Adds static or computed metadata to every serialized response.

**Depends on:** the `:root` plugin must be loaded before `:metadata`.

## When to use

- Every response should carry an API version, feature flags, or request-level info.
- Pagination data needs to be attached alongside the serialized records.
- Metadata should be omitted when nil or empty to keep responses clean.

## Setup

```ruby
class AppSerializer < Serega
  plugin :root
  plugin :metadata
end
```

## Defining metadata attributes

Use the class method `meta_attribute` to declare metadata:

```ruby
class AppSerializer < Serega
  plugin :root
  plugin :metadata

  meta_attribute(:version, const: "1.2.3")

  meta_attribute(:meta, :paging, hide_nil: true) do |records, ctx|
    next unless records.respond_to?(:total_count)
    { page: records.page, per_page: records.per_page, total_count: records.total_count }
  end
end

AppSerializer.to_h(nil)
# => { data: nil, version: "1.2.3" }
```

The `*path` arguments define nested hash keys. A single-element path like `(:version)` creates a top-level key; a multi-element path like `(:meta, :paging)` creates `{ meta: { paging: ... } }`.

## Full reference

`meta_attribute(*path, **options, &block)`

| Option | Description |
|---|---|
| `:const` | Constant value to include every time. |
| `:value` | Any callable (`#call`) that returns the value. Receives `(object, context)`. |
| `:hide_nil` | Skip this metadata key when the value is `nil`. Default: `false`. |
| `:hide_empty` | Skip this metadata key when the value is `nil` or empty. Default: `false`. |
| `&block` | Block to compute the value. Receives `(object, context)`. |

Metadata attributes are inherited by subclasses.

---

**Next:** [context_metadata](context_metadata.md)
