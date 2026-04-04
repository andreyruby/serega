# Batch Loading

Avoid N+1 queries by loading associated data in batches instead of fetching each association individually.

## Problem

When serializing a collection, accessing an association on each object individually causes N queries for N objects:

```ruby
class UserSerializer < Serega
  attribute :comments_count do |user|
    user.comments.count  # Runs a query for every user
  end
end

# Serializing 100 users = 1 + 100 queries
```

Batch loading collects all objects first, then loads the associated data in a single call.

## How it works

1. Serega serializes all objects in the collection
2. Before resolving batch-loaded attributes, it collects all the object IDs
3. Calls the loader once with all IDs
4. Maps results back to each object

## Named loaders

Define a named loader with the `batch` class method, then reference it from attributes:

```ruby
class UserSerializer < Serega
  # Define named loader: receives array of users, returns hash of { user_id => count }
  batch :comments_count, ->(users) { Comment.where(user: users).group(:user_id).count }

  # Use it — full form
  attribute :comments_count,
    batch: { use: :comments_count },
    value: proc { |user, batch:| batch[:comments_count][user.id] }

  # Shorter: id: :id is the default
  attribute :comments_count, batch: { use: :comments_count, id: :id }

  # Shortest: uses attribute name as loader key; id defaults to config.batch_id_option (:id)
  attribute :comments_count, batch: true
end
```

## Inline loaders

Provide a callable directly without defining a named loader:

```ruby
class UserSerializer < Serega
  attribute :followers_count,
    batch: { use: ->(users) { Follow.where(user: users).group(:user_id).count } }
end
```

## Callable class loaders

Use a callable class that responds to `.call` (class method):

```ruby
class LikesCountLoader
  def self.call(users)
    Like.where(user: users).group(:user_id).count
  end
end

class UserSerializer < Serega
  attribute :likes_count, batch: { use: LikesCountLoader }
end
```

## Multiple loaders per attribute

Load data from multiple sources and combine the results:

```ruby
class UserSerializer < Serega
  batch :facebook_likes, FacebookLikesLoader
  batch :twitter_likes, TwitterLikesLoader

  attribute :total_likes,
    batch: { use: [:facebook_likes, :twitter_likes] },
    value: proc { |user, batch:| batch[:facebook_likes][user.id] + batch[:twitter_likes][user.id] }
end
```

## Shortest form

For attributes where the attribute name matches the loader key and you use the default ID option:

```ruby
class UserSerializer < Serega
  batch :comments_count, ->(users) { Comment.where(user: users).group(:user_id).count }
  attribute :comments_count, batch: true
end
```

When using `batch: true`, the id method defaults to `config.batch_id_option` (`:id` by default). See [Configuration](configuration.md) to customize this.

## Examples

See `examples/batch_loader.rb`, `examples/batch_preload_mix_1.rb` through `examples/batch_preload_mix_6.rb` for complete working examples.

---

→ Next: [Preloads](preloads.md)
