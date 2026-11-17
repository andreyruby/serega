# Configuration

Set config in a base serializer. Child serializers inherit it and can change
it.

```ruby
class AppSerializer < Serega
  configure do |config|
    config.auto_preload = true
    config.hide_by_default = :auto
    config.base_serializer = self
  end
end
```

`config` changes an option without the block too:

```ruby
class UserSerializer < AppSerializer
  config.compact = true
end
```

Set config before defining attributes. An attribute reads the config when it is
defined, so a later change to `auto_preload`, `hide_by_default`,
`key_transform`, `batch_id_option` or `base_serializer` affects only attributes
defined after it.

## Options

| Option | Default | Description |
|---|---|---|
| `auto_preload` | `false` | Adds [preloads][automatic-preloads] to `:delegate` and `:serializer` attributes |
| `auto_preload_excluded_methods` | `[:itself, :__getobj__]` | Methods never preloaded automatically |
| `hide_by_default` | `false` | Hides attributes, see [Hiding by default](selecting-fields.md#hiding-by-default) |
| `key_transform` | `nil` | Changes attribute keys, see [camelCase and other key styles][key-styles] |
| `compact` | `false` | [Leaves out keys with `nil` values](conditional-attributes.md#leaving-out-nil-values) |
| `base_serializer` | `nil` | Superclass of [block-defined serializers][block-serializers] |
| `batch_id_option` | `:id` | Method that returns the id of an object for [batch loaders][batch-ids] |
| `delegate_default_allow_nil` | `false` | Default `allow_nil:` of [delegates](attributes.md#delegate) |
| `hash_access.default_mode` | `:symbol` | Mode of `hash_access: true`. See [Hash records][hash-mode] |
| `hash_access.default_allow_missing_key` | `false` | `nil` for missing Hash keys |
| `check_attribute_name` | `true` | Allows only `a-z`, `A-Z`, `0-9`, `_`, `-`, `~` in attribute names |
| `require_many` | `false` | Requires [`:many`](relations.md#many) on relations |
| `many` | `nil` | Serializes as a list (`true`) or one object (`false`) without a `:many` option; `nil` detects lists |
| `max_cached_plans_per_serializer_count` | `20` | [Plans cached][plan-cache] per serializer, `0` disables the cache |
| `depth_limit` | `nil` | Deepest nesting of serialized fields, see [Limiting nesting depth][depth-limit] |
| `deprecation_warnings` | `true` | Warns when a [deprecated plugin][root-metadata] loads |

[automatic-preloads]: preloads.md#automatic-preloads
[root-metadata]: root-and-metadata.md
[block-serializers]: relations.md#nested-serializers-defined-with-a-block
[key-styles]: camel-case.md
[batch-ids]: batch-loading.md#records-without-an-id
[hash-mode]: hash-records.md#default-access-mode
[plan-cache]: serializing.md#plan-cache
[depth-limit]: relations.md#limiting-nesting-depth
