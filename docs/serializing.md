# Serializing

```ruby
class UserSerializer < Serega
  attribute :username
  attribute :posts, serializer: PostSerializer
end

UserSerializer.to_h(user)
# => {username: "batman", posts: [{title: "Gotham at night"}]}

UserSerializer.to_h([user])
# => [{username: "batman", posts: [{title: "Gotham at night"}]}]

UserSerializer.to_h(nil) # => nil
```

`.call` is an alias of `.to_h`. Both accept the [field
selection](selecting-fields.md) options `:only`, `:except` and `:with`, and the
serialization options:

- `:context` — data for attribute values and conditions, see
  [Context](context.md);
- `:many` — serializes the object as a list (`true`) or as one object
  (`false`). By default, an `Enumerable` that is not a `Hash` or `Struct` is a
  list. Serega remembers the answer for the class of the object. Pass it when
  you know, to skip the check.

The options are keyword arguments. Pass a Hash of options with `**`:

```ruby
UserSerializer.to_h(user, **options)
```

An unknown option raises `ArgumentError`. With the `:root` or
`:context_metadata` plugin, it raises `Serega::SeregaError`.

## JSON

Serega returns Hashes. Convert them to JSON with any JSON library:

```ruby
JSON.generate(UserSerializer.to_h(user))

render json: UserSerializer.to_h(user) # Rails
```

## Struct and Data results

`.to_struct` returns `Struct` objects and `.to_data` returns `Data` objects,
nested relations included. `.to_struct` is as fast as `.to_h`.

```ruby
UserSerializer.to_struct(user)
# => #<struct username="batman", posts=[#<struct title="Gotham at night">]>

UserSerializer.to_data(user)
# => #<data username="batman", posts=[#<data title="Gotham at night">]>

UserSerializer.to_data(user).posts.first.title # => "Gotham at night"
```

An attribute named `initialize` or a name that Ruby does not accept as a
member, for example `name=`, raises `Serega::SeregaError`. A member named like
a method of `Struct` or `Data`, for example `hash`, replaces this method in the
result.

## Reusing a serializer

A serializer instance prepares its serialization plan once. Reuse it to
serialize many times with the same fields. Its methods take the
serialization options:

```ruby
serializer = UserSerializer.new(only: [:username])
serializer.to_h(user, many: false)
serializer.to_struct(users, context: {current_user: current_user})
```

Class methods cache plans too: `config.max_cached_plans_per_serializer_count`
keeps up to 20 plans per serializer by default. See
[Configuration](configuration.md).
