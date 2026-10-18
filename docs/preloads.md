# Preloads

The `:preload` attribute option names associations to load before
serialization. Serega collects the preloads of the requested fields only, and
loads each once for all serialized objects.

```ruby
class AppSerializer < Serega
  plugin :activerecord_preloads
end

class UserSerializer < AppSerializer
  attribute :name
  attribute :followers_count, preload: :user_stats, value: proc { |user| user.user_stats.followers_count }
  attribute :albums, serializer: AlbumSerializer, preload: :albums
end

class AlbumSerializer < AppSerializer
  attribute :title
  attribute :downloads_count, preload: :downloads, value: proc { |album| album.downloads.size }
end

UserSerializer.to_h(users)
# 1 query for user_stats of all users
# 1 query for albums of all users
# 1 query for downloads of all albums

UserSerializer.to_h(users, only: :name)
# no preloads
```

The `:preload` value is passed to the preload handler as is: a Symbol, Array,
Hash, or any value your handler understands. `preload: false` and
`preload: nil` disable preloading for the attribute.

## Automatic preloads

`config.auto_preload = true` adds preloads automatically:

- `delegate: {to: :user_stats}` preloads `:user_stats`;
- `serializer: AlbumSerializer` or an attribute block preloads the association
  with the attribute's name or `:method`.

```ruby
class AppSerializer < Serega
  plugin :activerecord_preloads
  config.auto_preload = true
end

class UserSerializer < AppSerializer
  attribute :comments_count, delegate: {to: :user_stats} # preloads :user_stats
  attribute :albums, serializer: AlbumSerializer           # preloads :albums
  attribute :tracks, serializer: TrackSerializer, preload: {albums: :tracks}
end
```

Use `config.auto_preload = {has_delegate_option: true}` or
`{has_serializer_option: true}` to enable one of them. A `:preload` option
replaces the automatic preload. Attributes with `:batch` and methods listed in
`config.auto_preload_excluded_methods` (`:itself` and `:__getobj__` by default)
are not preloaded:

```ruby
# Serializes the same user, preloading only what UserStatisticsSerializer declares
attribute :statistics, method: :itself, serializer: UserStatisticsSerializer
```

## Expensive fields on request

`config.hide_by_default = :auto` hides attributes with preloads or batch
loaders. Clients request them explicitly, and only then are they loaded.

```ruby
class AppSerializer < Serega
  plugin :activerecord_preloads
  config.auto_preload = true
  config.hide_by_default = :auto
end

UserSerializer.to_h(users)
# => [{name: "Bruce"}, ...], no preloads

UserSerializer.to_h(users, with: [:followers_count, {albums: :downloads_count}])
# preloads user_stats and albums for users, downloads for albums
```

## Custom preloading

The `:activerecord_preloads` plugin registers a preload handler. For another
ORM or for plain Ruby objects, register your own with `preload_with`:

```ruby
class AppSerializer < Serega
  preload_with { |objects, preloads| RecordPreloader.call(objects, preloads) }
  # or any callable with (objects, preloads)
  preload_with AppPreloader
end
```

The handler receives the objects to serialize and the `:preload` value of one
attribute. Child serializers inherit it. A `:preload` option without a handler
raises `Serega::SeregaError` on serialization.

The handler runs once per attribute with a preload. When several attributes
share a `:preload` value, it runs once for each of them over the same objects,
so it should skip data that is already loaded. The `:activerecord_preloads`
handler skips loaded associations.

The `:preload` value can be any value, so it can also tell the handler where to
load data from:

```ruby
class PostSerializer < AppSerializer
  attribute :owner, serializer: UserSerializer, preload: :owner
  attribute :author, serializer: UserSerializer, preload: :author

  preload_with do |posts, preloads|
    case preloads
    when :owner then OwnersLoader.call(posts)       # from the database
    when :author then AuthorsApi.load_into(posts)   # from an external API
    end
  end
end
```
