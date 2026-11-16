# Relations

A relation is an attribute serialized with another serializer: an attribute
with the `:serializer` option, or with a block that defines a
[nested serializer](#nested-serializers-defined-with-a-block).

```ruby
class PostSerializer < Serega
  attribute :title
end

class UserSerializer < Serega
  attribute :username
  attribute :posts, serializer: PostSerializer, many: true
end

UserSerializer.to_h(user)
# => {username: "batman", posts: [{title: "Gotham at night"}]}
```

## Table of Contents

<!-- toc -->

- [Relation options](#relation-options)
   - [`:serializer`](#serializer)
   - [`:many`](#many)
   - [`:preset`](#preset)
   - [`:only`, `:with`, `:except`](#only-with-except)
   - [`:preload`](#preload)
- [Nested serializers defined with a block](#nested-serializers-defined-with-a-block)
- [Limiting nesting depth](#limiting-nesting-depth)

<!-- tocstop -->

## Relation options

### `:serializer`

Serializes the value with another serializer. Use a String or a Proc when
serializers refer to each other.

```ruby
attribute :posts, serializer: PostSerializer
attribute :posts, serializer: "PostSerializer"
attribute :posts, serializer: -> { PostSerializer }
# => {posts: [{title: "Gotham at night"}]}
```

### `:many`

Serega serializes a value as a list when it is an `Enumerable`, except `Hash`
and `Struct`. `many: true` marks a list explicitly and serializes `nil` as
`[]`.

```ruby
attribute :posts, serializer: PostSerializer, many: true
# => {posts: []} when user.posts is nil
# => {posts: [{title: "Gotham at night"}]} when user.posts is one post
```

`config.require_many = true` requires `:many` on every relation, an
attribute with `:serializer` or a block. A relation without `:many` raises
`Serega::SeregaError`.

```ruby
class AppSerializer < Serega
  config.require_many = true
  config.base_serializer = self
end

class PostSerializer < AppSerializer
  attribute :comments, serializer: CommentSerializer, many: true
  attribute :author, many: false do
    attribute :name
  end
end
```

### `:preset`

Serializes the fields of a preset of the relation serializer by default. The
options of the call merge with the preset. See [Preset on a relation](presets.md#preset-on-a-relation).

```ruby
attribute :posts, serializer: PostSerializer, many: true, preset: :summary
# => {posts: [{id: 1, title: "Gotham at night"}]}
```

### `:only`, `:with`, `:except`

Select the fields of the relation by default, like the same options of a
call. See [Field selection options of a relation](presets.md#field-selection-options-of-a-relation).

```ruby
attribute :posts, serializer: PostSerializer, many: true, only: [:id, :title]
# => {posts: [{id: 1, title: "Gotham at night"}]}
```

### `:preload`

Names the associations to preload for the value, so the value is read without
N+1 queries. See [Preloads](preloads.md).

```ruby
attribute :email, preload: :emails, value: proc { |user| user.emails.find(&:verified?) }
```

## Nested serializers defined with a block

A block defines an anonymous nested serializer for the attribute value. The
value is found as usual, by the attribute name or the `:method`, `:value`,
`:delegate` or `:batch` option.

```ruby
class UserSerializer < AppSerializer
  attribute :first_name

  # user.profile
  attribute :profile do
    attribute :city
  end

  # The user itself, with only its counters
  attribute :statistics, method: :itself do
    attribute :likes_count
    attribute :comments_count
  end
end

UserSerializer.to_h(user)
# => {first_name: "Bruce", profile: {city: "Gotham"}, statistics: {likes_count: 10, comments_count: 3}}
```

The nested serializer is a subclass of a base serializer, set with
`config.base_serializer` or the `base_serializer:` attribute option. The
attribute option takes precedence. An attribute block raises
`Serega::SeregaError` when neither is set.

```ruby
attribute :statistics, method: :itself, base_serializer: StatisticsSerializer do
  attribute :likes_count
end
```

The nested serializer inherits everything from its base serializer: plugins,
config, attributes, batch loaders and the preload handler. Anything else can be
declared inside the block:

```ruby
attribute :statistics, method: :itself do
  batch :statistics, ->(users) { Statistics.for_users(users) } # => {user_id => statistics}

  attribute :likes_count, batch: :statistics,
    value: proc { |user, batches:| batches[:statistics][user.id].likes }
end
```

Good to know:

- The nested serializer is created when the attribute is defined. Later
  changes to the base serializer do not reach it.
- With a [presenter](presenter.md), `method: :itself` serializes the presenter.
  `method: :__getobj__` serializes the original object.
- Errors name the nested serializer and the line where the attribute is
  defined:

  ```text
  (when serializing the 'likes_count' attribute in UserSerializer.<statistics>, app/serializers/user_serializer.rb:12)
  ```

## Limiting nesting depth

`config.depth_limit` guards against expensive requests and cyclic relations.
The fields of the serializer itself are depth 1, so `1` allows no relations
and `2` allows one level of relations. The limit of the serializer that starts
the serialization applies to all nested serializers.

The limit counts only relations, the attributes with a `:serializer`. It does
not check attribute values: a Hash or an Array that a value returns is
serialized as it is, at any depth.

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

`Serega::DepthLimitError#details` shows the path, and on the next line the
serializer whose limit applies:

```text
UserSerializer (depth limit: 2) -> friends -> friends
(hint: if the nesting is not a cycle, increase config.depth_limit of UserSerializer)
```

The message is `Depth limit was exceeded`, safe to show to API clients.

Without a limit, relations that nest in a cycle raise `Serega::DepthLimitError`
with the message `Relations nest in a cycle`. A cycle is a relation that
selects the same fields of a serializer that a level above it already selects,
for example `friends` shown by default in `UserSerializer`:

```ruby
class UserSerializer < Serega
  attribute :friends, serializer: -> { UserSerializer }
end

UserSerializer.to_h(user)
# => Serega::DepthLimitError: Relations nest in a cycle
```

```text
UserSerializer -> friends
(hint: hide a relation of the cycle or set config.depth_limit)
```

The limit is checked when the serialization plan is built, before any
serialization. Call `UserSerializer.new(with: params[:with])` early to
validate a request before running other code.
