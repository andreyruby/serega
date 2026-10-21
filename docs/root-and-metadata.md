# Root Key and Metadata

## Root key

`plugin :root` wraps results in a root key, `:data` by default.

```ruby
class UserSerializer < Serega
  plugin :root
  attribute :username
end

UserSerializer.to_h(user)   # => {data: {username: "batman"}}
UserSerializer.to_h([user]) # => {data: [{username: "batman"}]}
```

Other keys:

```ruby
plugin :root, root: :users                       # one key for objects and lists
plugin :root, root_one: :user, root_many: :users # separate keys
plugin :root, root: nil                          # no root unless given per serialization
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

## Metadata

`plugin :metadata` adds metadata defined with `meta_attribute` next to the
[root key](#root-key). Load `plugin :root` first.

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

## Metadata per serialization

`plugin :context_metadata` adds metadata given per serialization with the
`:meta` option. Load `plugin :root` first.

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
