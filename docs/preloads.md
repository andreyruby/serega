# Preloads

Serega lets each attribute declare what association it needs via the `:preload` option. Serega then collects those declarations from all selected attributes and builds a merged hash.

**Important:** Serega does not load anything automatically. It only builds a hash. What you do with that hash is up to you — or up to a plugin.

---

## What preloads are

Each attribute can declare a `:preload` option naming the association it needs. When you instantiate a serializer, Serega builds a hash of all preloads required by the selected fields. Attributes that are not selected do not contribute their preloads to the hash.

```ruby
class UserSerializer < Serega
  attribute :username
  attribute :posts, serializer: PostSerializer, preload: :posts
  attribute :avatar, serializer: AvatarSerializer, preload: :avatar
end

UserSerializer.new(only: [:username, :posts]).preloads  # => { posts: {} }
UserSerializer.new(only: [:username]).preloads           # => {}
UserSerializer.new.preloads                              # => { posts: {}, avatar: {} }
```

The `preloads` instance method returns this hash. Nothing has been loaded at this point.

---

## Using preloads manually

You can retrieve the preloads hash and pass it to ActiveRecord (or any other tool) yourself:

```ruby
user = User.find(1)
serializer = UserSerializer.new(with: [:posts])

serializer.preloads  # => { posts: {} }

ActiveRecord::Associations::Preloader.new(
  records: [user],
  associations: serializer.preloads
).call

serializer.to_h(user)
```

For automatic preloading with ActiveRecord, see the [activerecord_preloads plugin](plugins/activerecord_preloads.md).

---

## `auto_preload` config

Setting `config.auto_preload` tells Serega to infer a `:preload` automatically for certain attribute types, so you don't have to specify it on every attribute.

```ruby
class AppSerializer < Serega
  config.auto_preload = true  # shorthand for both options below

  # Or fine-grained:
  # config.auto_preload = { has_delegate_option: true, has_serializer_option: true }
end
```

With `auto_preload` enabled:

```ruby
class UserSerializer < AppSerializer
  # preload: :user_stats inferred automatically from the :delegate option
  attribute :followers_count, delegate: { to: :user_stats }

  # preload: :albums inferred automatically from the :serializer option
  attribute :albums, serializer: AlbumSerializer
end
```

The two fine-grained keys are:

| Key | When a `:preload` is added |
|---|---|
| `has_delegate_option: true` | Attribute uses `:delegate`; the delegated-to association name is used |
| `has_serializer_option: true` | Attribute uses `:serializer` (without `:batch`); the attribute name is used |

You can still override the inferred value by specifying `:preload` explicitly on the attribute.

---

## `auto_hide` config

Setting `config.auto_hide` hides attributes that have a `:preload` or `:batch` option from the default output. Hidden attributes must be explicitly requested via `with:`. This avoids unnecessary queries when those attributes are not needed.

```ruby
class AppSerializer < Serega
  config.auto_hide = true  # shorthand for both options below

  # Or fine-grained:
  # config.auto_hide = { has_preload_option: true, has_batch_option: true }
end
```

Example:

```ruby
class UserSerializer < AppSerializer
  attribute :username
  attribute :posts, serializer: PostSerializer, preload: :posts  # hidden by default
end

UserSerializer.new.preloads             # => {}  (posts not selected)
UserSerializer.new(with: :posts).preloads  # => { posts: {} }
```

`auto_hide` and `auto_preload` compose naturally:

```ruby
class UserSerializer < AppSerializer
  # With both config.auto_preload and config.auto_hide enabled:
  # - preload: :albums is added automatically (auto_preload)
  # - the albums attribute is hidden by default (auto_hide)
  attribute :albums, serializer: AlbumSerializer
end
```

The two fine-grained keys for `auto_hide` are:

| Key | When an attribute is hidden |
|---|---|
| `has_preload_option: true` | Attribute has a `:preload` option (explicit or auto-added) |
| `has_batch_option: true` | Attribute uses `:batch` loading |

---

## Three specific cases

### Case 1: Serializing the same object as an association

When you want to pass the current object to a nested serializer without loading any association, set `preload: nil` to opt out. The nested serializer's own preloads will then apply to the same object level.

```ruby
class UserSerializer < AppSerializer
  attribute :user_stats,
    serializer: UserStatSerializer,
    value: proc { |user| user },  # same object, no real association
    preload: nil                  # no association to preload; nested preloads stay on the same object
end
```

### Case 2: Merging multiple associations into one serialized array

When two associations are combined and serialized as a single array, list both association names in `:preload` and specify a `:preload_path` so Serega knows where to route each set of nested preloads.

```ruby
class UserSerializer < AppSerializer
  attribute :profiles,
    serializer: ProfileSerializer,
    value: proc { |user| [user.new_profile, user.old_profile] },
    preload: [:new_profile, :old_profile],
    preload_path: [[:new_profile], [:old_profile]]  # one path per association
end
```

### Case 3: Preloading through a nested association

When the serialized value is reached through an intermediate association, specify the full preload hash and set `:preload_path` to point at the key where nested preloads should be appended.

```ruby
attribute :image,
  preload: { attachment: :blob },
  preload_path: [:attachment],          # nested preloads from ImageSerializer go here
  serializer: ImageSerializer,
  value: proc { |record| record.attachment }
```

This causes the resulting hash to be `{ attachment: { blob: { ...nested... } } }` rather than `{ attachment: { blob: {} }, ...nested... }`.

---

## Runnable examples

- `examples/preloads.rb` — demonstrates preload tracking with ActiveRecord
- `examples/batch_preload_mix_*.rb` — batch loading combined with preloads

---

## Next

→ [Configuration](configuration.md)
