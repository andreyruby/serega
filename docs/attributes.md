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

## Table of Contents

<!-- toc -->

- [All options](#all-options)
- [Shared config in a base serializer](#shared-config-in-a-base-serializer)
- [Configure before the first serialization](#configure-before-the-first-serialization)
- [Attribute values](#attribute-values)
   - [`:method`](#method)
   - [`:value`](#value)
   - [`:delegate`](#delegate)
   - [`:const`](#const)
   - [`:default`](#default)
   - [Other sources](#other-sources)
- [Hidden attributes](#hidden-attributes)
- [Relations](#relations)
- [Conditions and formatting](#conditions-and-formatting)
- [Attribute names](#attribute-names)
- [Listing attributes](#listing-attributes)

<!-- tocstop -->

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
| `serializer` | [Serialize with another serializer](relations.md#serializer) |
| `many` | [Mark a list](relations.md#many) |
| `preset` | [Serialize the fields of a preset of the relation](relations.md#preset) |
| `only`, `with`, `except` | [Select the fields of the relation](relations.md#only-with-except) |
| `preload` | [Preload associations](relations.md#preload) |
| `base_serializer` | [Base of a block-defined serializer](relations.md#nested-serializers-defined-with-a-block) |
| `if`, `unless`, `if_value`, `unless_value` | [Conditional attributes](conditional-attributes.md) |
| `format` | [Format the value](formatters.md) |

## Shared config in a base serializer

A base serializer can hold the plugins and config your app uses. Every
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

## Configure before the first serialization

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

An attribute with `:serializer`, or with a block, serializes its value with
another serializer. See [Relations](relations.md).

```ruby
attribute :posts, serializer: PostSerializer, many: true
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

The name is the serialized key as is. A camelCase key reads its value with
`:method`:

```ruby
attribute :firstName, method: :first_name
# => {firstName: "Bruce"}
```

For camelCase keys in every serializer, see [camelCase Keys](camel-case.md).

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
