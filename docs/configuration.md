# Configuration

Set config in a base serializer. Child serializers inherit it and can change
it.

```ruby
class AppSerializer < Serega
  config.auto_preload = true
  config.hide_by_default = :auto
  config.base_serializer = self
end
```

Set config before defining attributes. An attribute reads the config when it is
defined, so a later change to `auto_preload`, `hide_by_default`,
`batch_id_option` or `base_serializer` affects only attributes defined after
it.

## Options

| Option | Default | Description |
|---|---|---|
| `auto_preload` | `false` | Adds [preloads][automatic-preloads] to `:delegate` and `:serializer` attributes |
| `auto_preload_excluded_methods` | `[:itself, :__getobj__]` | Methods never preloaded automatically |
| `hide_by_default` | `false` | Hides attributes, see [Hiding by default](selecting-fields.md#hiding-by-default) |
| `base_serializer` | `nil` | Superclass of [block-defined serializers][block-serializers] |
| `batch_id_option` | `:id` | Method that returns the id of an object for [batch loaders](batch-loading.md#object-ids) |
| `delegate_default_allow_nil` | `false` | Default `allow_nil:` of [delegates](attributes.md#delegate) |
| `hash_access.default_mode` | `:symbol` | Mode of `hash_access: true`. See [Hash records](hash-records.md#defaults) |
| `hash_access.default_allow_missing_key` | `false` | `nil` for missing Hash keys |
| `check_attribute_name` | `true` | Allows only `a-z`, `A-Z`, `0-9`, `_`, `-`, `~` in attribute names |
| `check_initiate_params` | `true` | Raises on unknown fields in `:only`, `:except`, `:with` |
| `max_cached_plans_per_serializer_count` | `20` | Serialization plans cached per serializer, `0` disables the cache |
| `depth_limit` | `nil` | Deepest nesting of serialized fields, see [Depth limit](#depth-limit) |

## Depth limit

`config.depth_limit` guards against expensive requests and cyclic relations.
The limit of the serializer that starts the serialization applies to all
nested serializers.

```ruby
class AppSerializer < Serega
  config.depth_limit = 10
end

class UserSerializer < AppSerializer
  config.depth_limit = 2
  attribute :friends, serializer: -> { UserSerializer }, hide: true
end

UserSerializer.to_h(user, with: :friends) # depth 2
UserSerializer.to_h(user, with: {friends: :friends})
# => Serega::DepthLimitError: Depth limit was exceeded
```

`Serega::DepthLimitError#details` shows the path:
`UserSerializer (depth limit: 2) -> friends -> friends`.

The limit is checked when the serialization plan is built, before any
serialization. Call `UserSerializer.new(with: params[:with])` early to
validate a request before running other code.

## Plan cache

A serialization plan lists the fields to serialize. Serega caches plans by the
`:only`, `:except` and `:with` options as given, so `[:id, :name]` and
`"id,name"` are cached separately. The plan without these options is always
cached.

`config.root` and `config.context_metadata` are described in
[Root Key and Metadata](root-and-metadata.md).

[automatic-preloads]: preloads.md#automatic-preloads
[block-serializers]: attributes.md#nested-serializers-defined-with-a-block
