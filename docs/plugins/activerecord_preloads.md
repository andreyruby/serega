# Plugin :activerecord_preloads

Automatically preloads ActiveRecord associations to serialized objects before serialization begins.

## When to use

- Your serializer reads ActiveRecord associations and you want to avoid N+1 queries.
- You want preloading to happen without calling `includes` manually before passing data to the serializer.
- You use the `:preloads` plugin (or the `auto_preload_*` config flags) to declare which associations to load.

## Setup

```ruby
class AppSerializer < Serega
  plugin :activerecord_preloads
end
```

No options are accepted when loading this plugin.

## How it works

The plugin collects all `preload:` values declared on attributes (including attributes from nested serializers), merges them into a single associations hash, and passes that hash to `ActiveRecord::Associations::Preloader` before serialization runs.

## auto_preload config flags

When the following flags are set to `true`, the plugin infers preloads automatically without requiring an explicit `preload:` on each attribute:

```ruby
class AppSerializer < Serega
  config.auto_preload_attributes_with_delegate = true
  config.auto_preload_attributes_with_serializer = true
  config.auto_hide_attributes_with_preload = true

  plugin :activerecord_preloads
end

class UserSerializer < AppSerializer
  attribute :username                                         # no preload

  attribute :comments_count, delegate: { to: :user_stats }  # preloads :user_stats

  attribute :albums, serializer: AlbumSerializer, hide: false # preloads :albums
end

class AlbumSerializer < AppSerializer
  attribute :title                                            # no preload

  attribute :downloads_count,
    preload: :downloads,
    value: proc { |album| album.downloads.count }            # preloads :downloads
end

# UserSerializer.to_h(user) preloads { user_stats: {}, albums: { downloads: {} } }
```

## Manual preload override

Explicit `preload:` on an attribute always takes precedence:

```ruby
attribute :photo_count, preload: :photos, value: proc { |u| u.photos.size }
```

## Calling preload manually

`preload_associations_to` is available as an instance method when you need to preload without serializing:

```ruby
serializer = UserSerializer.new
serializer.preload_associations_to(user)
```

It returns the object unchanged when it is `nil` or an empty array.

---

**Next:** [formatters](formatters.md)
