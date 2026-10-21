# Attributes

A serializer is a class that lists attributes. Each attribute adds a key to the
result, and its options say where the value comes from.

```ruby
class UserSerializer < Serega
  attribute :first_name
  attribute :last_name
end

UserSerializer.to_h(user) # => {first_name: "Bruce", last_name: "Wayne"}
```

## Base serializer

Define one base serializer with the plugins and config your app uses. Every
serializer inherits plugins, config and attributes from its superclass.

```ruby
class AppSerializer < Serega
  plugin :activerecord_preloads
  config.auto_preload = true
  config.base_serializer = self # nested serializers defined with a block inherit AppSerializer
end

class UserSerializer < AppSerializer
  attribute :first_name
end

class CommentSerializer < AppSerializer
  attribute :text
end
```

## Locked serializers

Configure a serializer fully before it serializes anything. A serializer is
locked after its first serialization, directly or as a nested serializer.

```ruby
UserSerializer.to_h(user)

UserSerializer.attribute :nickname
# => Serega::SeregaError: UserSerializer can not be changed after it was used for serialization

UserSerializer.config.auto_preload = false
# => FrozenError

class AdminSerializer < UserSerializer
  attribute :nickname # subclasses of a locked serializer can be changed
end
```

A locked serializer raises `Serega::SeregaError` on new attributes, plugins,
batch loaders, presenter methods, meta attributes, `preload_with` and
`prepare_initial_objects` handlers, and `FrozenError` on config changes.

## Attribute values

By default, the value is the result of the method with the attribute name:
`attribute :first_name` reads `user.first_name`. The options below change that.

### `:method`

Reads the value from another method.

```ruby
attribute :name, method: :first_name # user.first_name
# => {name: "Bruce"}
```

With [`:hash_access`](hash-records.md), `:method` names a Hash key.

### `:value`

Computes the value with a Proc or any object that responds to `#call`.

```ruby
attribute :full_name, value: proc { |user| "#{user.first_name} #{user.last_name}" }
attribute :current, value: proc { |user, ctx| user == ctx[:current_user] }
attribute :current, value: proc { |user, ctx:| user == ctx[:current_user] }
attribute :api_version, value: proc { 2 }
attribute :full_name, value: FullName # FullName.call(user)
```

The callable receives the object to serialize and, optionally, the
[context](context.md) as a second parameter or the `:ctx` keyword. The
`:batches` keyword gives the results of the attribute's [batch loaders](batch-loading.md).

### `:delegate`

Reads the value from an associated object.

```ruby
attribute :city, delegate: {to: :profile}                          # user.profile.city
attribute :profile_name, delegate: {to: :profile, method: :first_name} # user.profile.first_name
attribute :city, delegate: {to: :profile, allow_nil: true}         # nil when user.profile is nil
```

Without `allow_nil: true`, a `nil` associated object raises `NoMethodError`.
`config.delegate_default_allow_nil = true` makes `allow_nil: true` the default.
Delegates also read Hash records, see [Hash records](hash-records.md).

### `:const`

Serializes a constant value.

```ruby
attribute :type, const: "user"
# => {type: "user"}
```

### `:default`

Replaces a `nil` value.

```ruby
attribute :nickname, default: ""
attribute :active, default: false
attribute :city, delegate: {to: :profile, allow_nil: true}, default: "Unknown"
```

### Other sources

- [`:batch`](batch-loading.md) loads values for all serialized objects at once.
- [`:hash_access`](hash-records.md) reads values from Hash keys.

`:method`, `:value` and `:const` can not be combined, and `:batch` can not be
combined with `:method` or `:const`.

## Hidden attributes

`hide: true` excludes an attribute unless it is requested with `:with` or
`:only`. See [Selecting fields](selecting-fields.md).

```ruby
class UserSerializer < Serega
  attribute :first_name
  attribute :last_name, hide: true
end

UserSerializer.to_h(user)                   # => {first_name: "Bruce"}
UserSerializer.to_h(user, with: :last_name) # => {first_name: "Bruce", last_name: "Wayne"}
```

## Relations

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

## Conditions and formatting

```ruby
attribute :email, if: proc { |user, ctx| user == ctx[:current_user] }
attribute :email, if_value: :present?
attribute :created_at, format: :iso8601
```

See [Conditional attributes](conditional-attributes.md) for `:if`, `:unless`,
`:if_value` and `:unless_value`, and [Formatters](formatters.md) for `:format`.

## Attribute names

Attribute names may contain only `a-z`, `A-Z`, `0-9`, `_`, `-` and `~`, so
they can be used in URLs without escaping. Other names raise
`Serega::SeregaError`. `config.check_attribute_name = false` turns the check
off.

## Listing attributes

`.attributes` returns the attributes by name, hidden and inherited ones too:

```ruby
class UserSerializer < Serega
  attribute :username
  attribute :email, hide: true
end

class AdminSerializer < UserSerializer
  attribute :role
end

AdminSerializer.attributes.keys # => [:username, :email, :role]
```

## All options

| Option | Purpose |
|---|---|
| `method` | [Read another method](#method) |
| `value` | [Compute the value](#value) |
| `delegate` | [Read from an associated object](#delegate) |
| `const` | [Serialize a constant](#const) |
| `default` | [Replace `nil`](#default) |
| `batch` | [Load values for all objects at once](batch-loading.md) |
| `hash_access` | [Read Hash keys](hash-records.md) |
| `hide` | [Exclude unless requested](#hidden-attributes) |
| `serializer` | [Serialize with another serializer](#serializer) |
| `many` | [Mark a list](#many) |
| `preload` | [Preload associations](#preload) |
| `base_serializer` | [Base of a block-defined serializer](#nested-serializers-defined-with-a-block) |
| `if`, `unless`, `if_value`, `unless_value` | [Conditional attributes](conditional-attributes.md) |
| `format` | [Format the value](formatters.md) |
