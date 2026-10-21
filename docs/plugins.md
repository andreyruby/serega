# Plugins

Plugins add optional features. Enable them in a base serializer, and every
child serializer gets them.

```ruby
class AppSerializer < Serega
  plugin :activerecord_preloads
  plugin :string_modifiers
  plugin :root, root_one: :user, root_many: :users
end
```

| Plugin | Purpose |
|---|---|
| [`:activerecord_preloads`](#plugin-activerecord_preloads) | Preloads ActiveRecord associations |
| [`:string_modifiers`](#plugin-string_modifiers) | Accepts fields as `"name,posts(title)"` |
| [`:root`](#plugin-root) | Wraps results in a root key |
| [`:metadata`](#plugin-metadata) | Adds metadata defined in the serializer |
| [`:context_metadata`](#plugin-context_metadata) | Adds metadata given per serialization |
| [`:camel_case`](#plugin-camel_case) | Serializes keys in camelCase |
| [`:explicit_many_option`](#plugin-explicit_many_option) | Requires `:many` on relations |

## Plugin :activerecord_preloads

Loads every [`:preload`](preloads.md) of the requested fields once, with
`ActiveRecord::Associations::Preloader`.

```ruby
class AppSerializer < Serega
  plugin :activerecord_preloads
  config.auto_preload = true
end

class UserSerializer < AppSerializer
  attribute :username
  attribute :comments_count, delegate: {to: :user_stats} # preloads :user_stats
  attribute :albums, serializer: AlbumSerializer           # preloads :albums
end

class AlbumSerializer < AppSerializer
  attribute :downloads_count, preload: :downloads, value: proc { |album| album.downloads.size }
end

UserSerializer.to_h(users)
# 3 queries for any number of users and albums:
# user_stats of all users, albums of all users, downloads of all albums
```

The plugin registers a [`preload_with`](preloads.md#custom-preloading)
handler. It preloads ActiveRecord objects only and raises `Serega::SeregaError`
for other objects.

## Plugin :string_modifiers

Accepts `:only`, `:except` and `:with` as one String, with nested fields in
parentheses. See [Selecting fields](selecting-fields.md#fields-from-a-request).

```ruby
class AppSerializer < Serega
  plugin :string_modifiers
end

UserSerializer.to_h(bruce, only: "username,friends(first_name)")
# => {username: "batman", friends: [{first_name: "Alfred"}]}

UserSerializer.to_h(bruce, with: "friends", except: "friends(username)")
UserSerializer.to_h(bruce, with: {friends: :email}) # other forms keep working
```

## Plugin :root

Wraps results in a root key, `:data` by default.

```ruby
class UserSerializer < Serega
  plugin :root
  attribute :username
end

UserSerializer.to_h(user)   # => {data: {username: "batman"}}
UserSerializer.to_h([user]) # => {data: [{username: "batman"}]}
```

Plugin options:

```ruby
plugin :root, root: :users                     # one key for objects and lists
plugin :root, root_one: :user, root_many: :users # separate keys
plugin :root, root: nil                        # no root unless given per serialization
```

Per serialization:

```ruby
UserSerializer.to_h(user, root: :user) # => {user: {username: "batman"}}
UserSerializer.to_h(user, root: nil)   # => {username: "batman"}
```

`config.root.one` and `config.root.many` read and change the keys in child
serializers.

`.to_struct` and `.to_data` return a Hash with `Struct` or `Data` objects
under the root key:

```ruby
UserSerializer.to_struct(user) # => {data: #<struct username="batman">}
```

## Plugin :metadata

Adds metadata defined with `meta_attribute`. Load the [`:root`](#plugin-root)
plugin first.

```ruby
class AppSerializer < Serega
  plugin :root
  plugin :metadata

  meta_attribute :version, const: "1.2.3"
  meta_attribute :meta, :paging, hide_nil: true do |records, ctx|
    next unless records.respond_to?(:total_count)

    {page: records.current_page, total_count: records.total_count}
  end
end

UserSerializer.to_h(users.page(1))
# => {data: [...], version: "1.2.3", meta: {paging: {page: 1, total_count: 120}}}
```

`meta_attribute` accepts:

- a path of keys: `:meta, :paging` builds `{meta: {paging: value}}`;
- the value: `const:`, `value:` with a callable, or a block. Callables receive
  the serialized objects and the [context](context.md);
- `hide_nil: true` to skip `nil` values, `hide_empty: true` to skip `nil` and
  empty values.

## Plugin :context_metadata

Adds metadata given per serialization with the `:meta` option. Load the
[`:root`](#plugin-root) plugin first.

```ruby
class AppSerializer < Serega
  plugin :root
  plugin :context_metadata
end

UserSerializer.to_h(user, meta: {version: "1.0.1"})
# => {data: {username: "batman"}, version: "1.0.1"}
```

`plugin :context_metadata, context_metadata_key: :extra` or
`config.context_metadata.key = :extra` changes the option name. The previous
name raises `Serega::SeregaError`.

## Plugin :camel_case

Serializes attribute keys in camelCase. Keys are transformed once, when
attributes are defined.

```ruby
class AppSerializer < Serega
  plugin :camel_case
end

class UserSerializer < AppSerializer
  attribute :first_name
  attribute :last_name
  attribute :full_name, camel_case: false, value: proc { |user| "#{user.first_name} #{user.last_name}" }
end

UserSerializer.to_h(user)
# => {firstName: "Bruce", lastName: "Wayne", full_name: "Bruce Wayne"}

UserSerializer.to_h(user, only: :firstName) # select fields by camelCase names
# => {firstName: "Bruce"}
```

- `camel_case: false` keeps an attribute name as is.
- `plugin :camel_case, transform: ->(name) { name.camelize(:lower) }` sets a
  custom transformation.
- Keys of the `:root`, `:metadata` and `:context_metadata` plugins are not
  transformed.

## Plugin :explicit_many_option

Requires the `:many` option on every relation, an attribute with
`:serializer` or a block. Each relation states whether it is one object or a
list.

```ruby
class AppSerializer < Serega
  plugin :explicit_many_option
  config.base_serializer = self
end

class PostSerializer < AppSerializer
  attribute :author, many: false do
    attribute :name
  end

  attribute :comments, serializer: CommentSerializer, many: true
end
```

A relation without `:many` raises `Serega::SeregaError`.
