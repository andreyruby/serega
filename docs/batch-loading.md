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

## Table of Contents

<!-- toc -->

- [Defining loaders](#defining-loaders)
- [Using loaders](#using-loaders)
- [Values for the current user](#values-for-the-current-user)
- [Defaults and combined loaders](#defaults-and-combined-loaders)
- [Records without an `id`](#records-without-an-id)
- [Loading relations in batches](#loading-relations-in-batches)

<!-- tocstop -->

## Defining loaders

`batch` defines a named loader. Child serializers inherit it, and a child
that defines a loader with the same name uses its own, while the parent keeps
the original.

```ruby
class UserSerializer < Serega
  batch :likes_count, ->(users) { Like.where(user: users).group(:user_id).count }
  batch :views_count, ViewsCountLoader                          # responds to #call
  batch(:badges) { |users| Badge.for_users(users) }               # block
  batch :rank, ->(users, ctx) { Rank.for(users, ctx[:season]) }   # with context
  batch :rank, ->(users, ctx:) { Rank.for(users, ctx[:season]) }  # :ctx keyword
end
```

A loader with logic of its own fits a class in its own file, such as
`app/serializers/loaders/views_count_loader.rb`: any object that responds to
`#call` works, and it can be tested without a serializer.

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

Several attributes can use one loader. It runs once per serialization for all
of them:

```ruby
class UserSerializer < Serega
  batch :stats, ->(users) { UserStats.where(user: users).index_by(&:user_id) }

  attribute :likes_count, batch: :stats, value: proc { |user, batches:| batches[:stats][user.id].likes }
  attribute :views_count, batch: :stats, value: proc { |user, batches:| batches[:stats][user.id].views }
end
```

## Values for the current user

Values that depend on the current user, such as favorites or likes, read the
user from the [context](context.md). The loader returns only the ids with a
value, and `default:` fills in the others. For a guest, it returns an empty
Hash without a query.

```ruby
class FavoriteCoursesLoader
  def self.call(courses, ctx)
    user = ctx[:current_user]
    return {} unless user # a guest: no query

    course_ids = Favorite.where(user: user, course: courses).pluck(:course_id)
    course_ids.to_h { |id| [id, true] }
  end
end

class CourseSerializer < Serega
  attribute :title
  attribute :favorite, batch: FavoriteCoursesLoader, default: false
end

CourseSerializer.to_h(courses, context: {current_user: user})
# SELECT "favorites"."course_id" FROM "favorites" WHERE "favorites"."user_id" = 1 AND "favorites"."course_id" IN (1, 2)
# => [{title: "Anatomy", favorite: true}, {title: "Figure Drawing", favorite: false}]

CourseSerializer.to_h(courses, context: {current_user: nil})
# => [{title: "Anatomy", favorite: false}, {title: "Figure Drawing", favorite: false}]
```

## Defaults and combined loaders

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

## Records without an `id`

Values are looked up by `object.id`. The `:id` option or
`config.batch_id_option` choose another method:

```ruby
attribute :likes_count, batch: {use: :likes_count, id: :uuid}

class AppSerializer < Serega
  config.batch_id_option = :uuid
end
```

A foreign key works the same way. The loader returns the related records by
their ids, and `id:` names the key to look them up with. Records without the
key get `nil`, and the loader skips the request when no record has one:

```ruby
class LessonSerializer < Serega
  # Streams come from a video service, not the database
  batch :streams, lambda { |lessons|
    stream_ids = lessons.filter_map(&:stream_id)
    stream_ids.empty? ? {} : VideoService.streams(stream_ids).to_h { |stream| [stream.id, stream] }
  }

  attribute :title
  attribute :stream, serializer: StreamSerializer, batch: {use: :streams, id: :stream_id}
end
```

For an ActiveRecord `belongs_to`, a [preload](preloads.md) does the same: it
runs no query when every foreign key is `nil`.

## Loading relations in batches

A loader can return records for a relation serializer:

```ruby
class UserSerializer < Serega
  batch :posts, ->(users) { Post.where(user: users).group_by(&:user_id) }

  attribute :posts, batch: true, serializer: PostSerializer
end
```

The [preloads](preloads.md) of `PostSerializer` run for the loaded posts, so a
level can load with a batch and the next with preloads. For ActiveRecord
associations, preloads alone are usually simpler.
