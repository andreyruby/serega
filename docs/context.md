# Context

The context passes request data, like the current user, to a serialization.

```ruby
class UserSerializer < Serega
  attribute :email, value: proc { |user, ctx| user.email if user == ctx[:current_user] }
end

UserSerializer.to_h(user, context: {current_user: user})
# => {email: "bruce@wayne.com"}
```

The context is available as a second parameter or as the `:ctx` keyword in:

- [`:value`](attributes.md#value) callables;
- [`:if` and `:unless`](conditional-attributes.md) conditions;
- [formatters](formatters.md);
- [batch loaders](batch-loading.md);
- [`prepare_initial_objects`](prepare-initial-objects.md) handlers.

```ruby
class UserSerializer < Serega
  formatter :masked, ->(email, ctx) { ctx[:admin] ? email : "***" }
  batch :badges, ->(users, ctx:) { Badge.for(users, season: ctx[:season]) }

  attribute :email, format: :masked
  attribute :phone, if: proc { |user, ctx| ctx[:admin] }
  attribute :badge, batch: :badges
end
```

Serega passes the given context as is. Without the `:context` option, the
context is a frozen empty Hash.
