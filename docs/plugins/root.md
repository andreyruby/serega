# Plugin :root

Wraps the serialized output in a root key.

## When to use

- Your JSON API envelopes responses, e.g. `{ data: { ... } }`.
- Single-object and collection responses need different root keys (`user` vs `users`).
- You want a default root but need to remove it or change it for specific calls.

## Setup

```ruby
# Default root :data for both single and many
class UserSerializer < Serega
  plugin :root
end

# Same root for single and many
class UserSerializer < Serega
  plugin :root, root: :user
end

# Different roots for single and many
class UserSerializer < Serega
  plugin :root, root_one: :user, root_many: :users
end

# No root by default (can still be added per call)
class UserSerializer < Serega
  plugin :root, root: nil
end
```

Allowed plugin options: `:root`, `:root_one`, `:root_many`.

## Override per call

Pass `root:` to any serialization call to override the configured root for that call only:

```ruby
UserSerializer.to_h(user)               # => { data: { ... } }
UserSerializer.to_h(user, root: :person) # => { person: { ... } }
UserSerializer.to_h(user, root: nil)    # => { ... }  (no root)
```

## Config methods

```ruby
config.root.one         # => current root key for single-object serialization
config.root.many        # => current root key for collection serialization
config.root.one  = :user
config.root.many = :users
```

The root is determined automatically from whether the object is `Enumerable`, unless the `many:` serialize option is set explicitly.

---

**Next:** [metadata](metadata.md)
