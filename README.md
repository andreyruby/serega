# Serega Ruby Serializer

[![Gem Version](https://badge.fury.io/rb/serega.svg)](https://badge.fury.io/rb/serega)
[![GitHub Actions](https://github.com/aglushkov/serega/actions/workflows/main.yml/badge.svg?event=push)](https://github.com/aglushkov/serega/actions/workflows/main.yml)

Serega is a Ruby serializer that separates what attributes can be serialized from what gets included per request, with a plugin system that lets you load only what you need.

---

## Install

```
bundle add serega
```

---

## Quick example

```ruby
class AppSerializer < Serega
  # shared plugins and config go here
end

class PostSerializer < AppSerializer
  attribute :title
  attribute :published_at
end

class UserSerializer < AppSerializer
  attribute :name
  attribute :email
  attribute :posts, serializer: PostSerializer
end

user = User.find(1)

# Serialize everything
UserSerializer.to_h(user)
# => { name: "Bruce", email: "bruce@wayneenterprises.com",
#      posts: [{ title: "Hello", published_at: "2024-01-01" }] }

# Select only what you need
UserSerializer.to_h(user, only: [:name, { posts: [:title] }])
# => { name: "Bruce", posts: [{ title: "Hello" }] }

# Exclude specific fields
UserSerializer.to_h(user, except: [:email])
# => { name: "Bruce", posts: [{ title: "Hello", published_at: "2024-01-01" }] }
```

---

## Attribute options

```ruby
class UserSerializer < Serega
  attribute :name                                                    # calls user.name
  attribute :full_name, method: :display_name                       # calls a different method
  attribute(:email) { |user, ctx| user.email if ctx[:current_user] == user }  # block
  attribute :score,  value: proc { |user| user.score.round(2) }     # proc or callable
  attribute :city,   delegate: { to: :address }                     # user.address.city
  attribute :city,   delegate: { to: :address, method: :town }       # user.address.town
  attribute :type,   const: "user"                                  # constant value
  attribute :bio,    default: ""                                     # nil → ""
  attribute :token,  hide: true                                      # excluded by default, add with `with:`
  attribute :posts,  serializer: PostSerializer                      # nested serializer
  attribute :posts,  serializer: PostSerializer, many: true          # explicit has-many

  batch :comments_count, ->(users) { Comment.where(user: users).group(:user_id).count }
  attribute :comments_count, batch: true                             # batch-loaded, avoids N+1
end
```

→ [Full attribute options reference](docs/attributes.md) · [Batch Loading](docs/batch-loading.md)

---

## How it works

Attributes define what *can* be serialized. Modifiers (`only`, `except`, `with`) control what *is* serialized per request. Plugins extend behavior on demand — load only what your app needs.

---

## Efficient loading

When fields are selected dynamically, you only want to load what's actually needed — not fetch everything upfront.

Serega tracks which associations are needed based on the fields selected in each request. This means you can avoid unnecessary database queries when attributes are excluded.

Using ActiveRecord? The `activerecord_preloads` plugin handles loading automatically → [activerecord_preloads](docs/plugins/activerecord_preloads.md)

Need custom loading logic or non-ActiveRecord data sources? → [Batch Loading](docs/batch-loading.md)

→ [How preloads work](docs/preloads.md)

---

## Production tips

Most apps define a base serializer with shared plugins and config. All child serializers inherit it.

**Avoid loading associations that were not requested.**
Without this, every serialization call fetches all associations regardless of which fields were selected.
```ruby
config.auto_hide = true    # hide attributes with :preload or :batch by default
config.auto_preload = true # auto-detect needed associations from :serializer and :delegate
plugin :activerecord_preloads  # preload only what the current request actually needs
```
→ [activerecord_preloads](docs/plugins/activerecord_preloads.md) · [Preloads](docs/preloads.md)

**Apply consistent formatting for dates, money, and floats across all serializers.**
Without this, each attribute duplicates the same formatting logic.
```ruby
plugin :formatters, formatters: {
  iso8601:          ->(time)  { time.iso8601(3) },
  nullable_iso8601: ->(time)  { time&.iso8601(3) },
  round2:           ->(value) { value.round(2) }
}

attribute :created_at, format: :iso8601
attribute :price,      format: :round2
```
→ [formatters](docs/plugins/formatters.md)

**Add metadata (pagination, API version) to every response.**
Without this, clients have no structured way to receive pagination or versioning info alongside data.
```ruby
plugin :root
plugin :metadata

meta_attribute(:meta, :paging, hide_nil: true) do |records|
  next unless records.respond_to?(:total_count)
  { total_count: records.total_count, size: records.size, offset_value: records.offset_value }
end
```
→ [root](docs/plugins/root.md) · [metadata](docs/plugins/metadata.md)

**Skip field validation in production.**
Unknown field names raise errors. Validation has a small performance cost — catch these mistakes on staging and skip the check in production.
```ruby
config.check_initiate_params = !Rails.env.production?
```
→ [Configuration](docs/configuration.md)

**Allow nil on delegated attributes globally.**
Without this, every `delegate:` attribute that could have a nil parent needs `allow_nil: true` explicitly.
```ruby
config.delegate_default_allow_nil = true
```
→ [Attributes — :delegate](docs/attributes.md)

**Cache serialization plans for repeated requests.**
When the same field modifiers are used repeatedly, Serega rebuilds the plan each time by default.
```ruby
config.max_cached_plans_per_serializer_count = 50
```
→ [Configuration](docs/configuration.md)

**Limit serialization depth.**
Without this, a malicious or accidental deeply nested `with:` query can cause excessive data loading.
```ruby
plugin :depth_limit, limit: 10
```
→ [depth_limit](docs/plugins/depth_limit.md)

**Full production base serializer:**
```ruby
class AppSerializer < Serega
  plugin :root
  plugin :metadata
  plugin :context_metadata
  plugin :string_modifiers
  plugin :activerecord_preloads
  plugin :formatters, formatters: {
    iso8601:          ->(time)  { time.iso8601(3) },
    nullable_iso8601: ->(time)  { time&.iso8601(3) },
    round2:           ->(value) { value.round(2) }
  }
  plugin :depth_limit, limit: 10

  config.check_initiate_params          = !Rails.env.production?
  config.delegate_default_allow_nil     = true
  config.max_cached_plans_per_serializer_count = 50
  config.auto_hide                      = true
  config.auto_preload                   = true

  meta_attribute(:meta, :paging, hide_nil: true) do |records|
    next unless records.respond_to?(:total_count)
    { total_count: records.total_count, size: records.size, offset_value: records.offset_value }
  end
end
```

---

## Why Serega

- **Dynamic fields per request** — let clients choose exactly what's returned via `only/except/with` → [Selecting Fields](docs/selecting-fields.md)
- **Built-in batch loading** — load associations in a single pass per request → [Batch Loading](docs/batch-loading.md)
- **Rich opt-in plugin system** — conditional attributes, formatters, camelCase keys, presenters, depth limits — add only what you need → [Plugins](docs/plugins/README.md)

---

## Where to start

| I want to...                          | Read this                                                       |
|---------------------------------------|-----------------------------------------------------------------|
| Get up and running                    | [Getting Started](docs/getting-started.md)                      |
| Control which fields are returned     | [Selecting Fields](docs/selecting-fields.md)                    |
| Load associations efficiently          | [Batch Loading](docs/batch-loading.md) / [activerecord_preloads](docs/plugins/activerecord_preloads.md) |
| Explore all available plugins         | [Plugins](docs/plugins/README.md)                               |

→ [Full documentation](docs/README.md)
