# Prepare Initial Objects

`prepare_initial_objects` replaces the objects given to a serializer before
serialization. A serializer can accept ids and load the records itself.

```ruby
class UserSerializer < Serega
  prepare_initial_objects { |user_ids| User.where(id: user_ids) }

  attribute :first_name
end

UserSerializer.to_h(["17", "42"]) # => [{first_name: "Ann"}, {first_name: "Bob"}]
```

The handler is a block or any callable. It receives the given objects and,
optionally, the [context](context.md) as a second parameter or the `:ctx`
keyword:

```ruby
prepare_initial_objects { |ids, ctx| User.where(id: ids, account: ctx[:account]) }
prepare_initial_objects { |ids, ctx:| User.where(id: ids, account: ctx[:account]) }
prepare_initial_objects UsersLoader
```

## Single objects and lists

The handler runs before Serega decides whether to serialize a list, so its
result decides it:

```ruby
UserSerializer.to_h("17") # => [{first_name: "Ann"}], as User.where returns a list
```

A given `:many` option is used as is. A handler that returns `nil` serializes
`nil`.

## Preloads

[Preloads](preloads.md) are applied to the prepared objects:

```ruby
class UserSerializer < Serega
  plugin :activerecord_preloads
  prepare_initial_objects { |user_ids| User.where(id: user_ids) }

  attribute :albums_count, preload: :albums, value: proc { |user| user.albums.size }
end
```

[`plugin :activerecord_preloads`](preloads.md#activerecord)
preloads ActiveRecord objects only, and raises `Serega::SeregaError` for other
objects. For read-only records, Structs or Hashes, use
[batch loading](batch-loading.md).

## Scope

- The handler runs for the objects given to the serializer only, not for
  objects of nested serializers.
- Subclasses inherit the handler. Declare it on the serializers that need it,
  not on a base serializer.
- Errors raised by the handler reach the caller unchanged.
