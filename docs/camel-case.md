# camelCase Keys

`config.key_transform = :camel_case` serializes `first_name` as `firstName`.
Set it in a base serializer to change the keys of all serializers:

```ruby
class AppSerializer < Serega
  config.key_transform = :camel_case
end

class PostSerializer < AppSerializer
  attribute :post_title
end

class UserSerializer < AppSerializer
  attribute :first_name
  attribute :recent_posts, serializer: PostSerializer, many: true
end

UserSerializer.to_h(user)
# => {firstName: "Bruce", recentPosts: [{postTitle: "Gotham at night"}]}
```

## Table of Contents

<!-- toc -->

- [Values come from the original names](#values-come-from-the-original-names)
- [Fields are selected by the new keys](#fields-are-selected-by-the-new-keys)
- [One camelCase key](#one-camelcase-key)
- [Other key styles](#other-key-styles)
- [When the transformation runs](#when-the-transformation-runs)

<!-- tocstop -->

## Values come from the original names

The key changes, the source does not: `first_name` still reads
`user.first_name`, and with [`hash_access`](hash-records.md) it reads
`record[:first_name]`. Options that name a method, such as `:method` and
`:delegate`, keep the Ruby names too.

## Fields are selected by the new keys

`only:`, `except:`, `with:`, presets, `.attributes` and the members of
`.to_struct` and `.to_data` use the camelCase keys, as clients see them:

```ruby
UserSerializer.to_h(user, only: "firstName,recentPosts(postTitle)")
# => {firstName: "Bruce", recentPosts: [{postTitle: "Gotham at night"}]}

preset :card, only: [:firstName, {recentPosts: :postTitle}] # in UserSerializer

UserSerializer.attributes.keys # => [:firstName, :recentPosts]
```

## One camelCase key

Without `key_transform`, the attribute name is the key as is. A single
camelCase key reads its value with `:method`:

```ruby
attribute :firstName, method: :first_name
# => {firstName: "Bruce"}
```

## Other key styles

A callable receives the name as a Symbol and returns the key. A String key
stays a String in the serialized Hash:

```ruby
config.key_transform = ->(name) { name.to_s.camelize(:lower) } # ActiveSupport
# => {"firstName" => "Bruce"}
```

Fields are still selected by the keys as Symbols: `only: :firstName`.

## When the transformation runs

`key_transform` changes the names of the attributes defined after it, so set
it before the attributes, in a base serializer. A related serializer uses its
own config, thus it needs the same base serializer.

The transformation runs once, when an attribute is defined, thus it costs
nothing during serialization.
