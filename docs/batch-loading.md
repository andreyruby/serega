# Batch Loading

A batch loader loads data for all serialized objects at once, so serializing
100 users runs one query, not 100.

```ruby
class UserSerializer < Serega
  batch :followers_count, ->(users) { Follow.where(user: users).group(:user_id).count }

  attribute :name
  attribute :followers_count, batch: true
end

UserSerializer.to_h(users)
# SELECT COUNT(*), user_id FROM follows WHERE user_id IN (1, 2, ...) GROUP BY user_id
# => [{name: "Bruce", followers_count: 7}, {name: "Alfred", followers_count: 3}]
```

A loader receives the objects and returns a Hash of values by object id. The
attribute value is `batches[:followers_count][user.id]`, `nil` for a missing
id.

A loader runs once per serialization for all objects of a relation: for
`users(posts(comments_count))`, the `comments_count` loader runs once for the
posts of all users. A loader of an attribute that is not serialized does not
run.

## Defining loaders

`batch` defines a named loader. Child serializers inherit it.

```ruby
class UserSerializer < Serega
  batch :likes_count, ->(users) { Like.where(user: users).group(:user_id).count }
  batch :views_count, ViewsCountLoader                          # responds to #call
  batch(:badges) { |users| Badge.for_users(users) }               # block
  batch :rank, ->(users, ctx) { Rank.for(users, ctx[:season]) }   # with context
  batch :rank, ->(users, ctx:) { Rank.for(users, ctx[:season]) }  # :ctx keyword
end
```

## Using loaders

```ruby
class UserSerializer < Serega
  # The loader named after the attribute. It must be defined before the attribute.
  attribute :likes_count, batch: true

  # A loader with another name
  attribute :likes, batch: :likes_count

  # A loader that belongs to this attribute
  attribute :followers_count, batch: ->(users) { Follow.where(user: users).group(:user_id).count }
end
```

`batch: true` and `batch: :name` raise `Serega::SeregaError` when no loader
with that name is defined.

## Building the value

`:value` builds the value from the loaded batches, for example to set a default
or combine several loaders. A loader given directly to the attribute is found
under the attribute name.

```ruby
attribute :followers_count, batch: true,
  value: proc { |user, batches:| batches[:followers_count].fetch(user.id, 0) }

attribute :likes_count, batch: {use: [:facebook_likes, :x_likes]},
  value: proc { |user, batches:| batches[:facebook_likes][user.id] + batches[:x_likes][user.id] }
```

Several loaders in `:use` require `:value`. For a simple fallback,
[`default:`](attributes.md#default) also works: `batch: true, default: 0`.

## Object ids

Values are looked up by `object.id`. The `:id` option or
`config.batch_id_option` choose another method:

```ruby
attribute :likes_count, batch: {use: :likes_count, id: :uuid}

class AppSerializer < Serega
  config.batch_id_option = :uuid
end
```

## Relations

A loader can return records for a relation serializer:

```ruby
class UserSerializer < Serega
  batch :posts, ->(users) { Post.where(user: users).group_by(&:user_id) }

  attribute :posts, batch: true, serializer: PostSerializer
end
```

For ActiveRecord associations, [preloads](preloads.md) are usually simpler.
