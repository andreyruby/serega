# Presenter

A `presenter` block holds computed attributes as methods, so the serializer
reads as a list of fields.

```ruby
class UserSerializer < Serega
  attribute :name
  attribute :role

  presenter do
    def name
      [first_name, last_name].compact.join(" ")
    end

    def role
      (id == __ctx__[:current_user_id]) ? :self : :other
    end
  end
end

UserSerializer.to_h(user, context: {current_user_id: 1})
# => {name: "Bruce Wayne", role: :self}
```

The same serializer with `:value` options:

```ruby
class UserSerializer < Serega
  attribute :name, value: proc { |user| [user.first_name, user.last_name].compact.join(" ") }
  attribute :role, value: proc { |user, ctx| (user.id == ctx[:current_user_id]) ? :self : :other }
end
```

## Inside presenter methods

Presenter methods run on a `SimpleDelegator` that wraps the serialized object:

- methods of the object are available directly, like `first_name` above;
- `__getobj__` returns the object;
- `__ctx__` returns the [context](context.md).

Objects are wrapped only when the serializer has presenter methods. Then
`:value` callables and batch loaders receive the wrapped objects, and preload
handlers receive the original objects.

## Speed

Presenter methods are slower than `:value` options: each object is wrapped,
and each attribute is read through the wrapper. 20 objects with 10
attributes, 2 of them computed, serialize in 11.7 µs with presenter methods and
in 6.3 µs with `:value` options, about twice as fast. The difference is a few
microseconds, thus it matters little in a request that takes milliseconds.

## Inheritance

`presenter` blocks add up. A child serializer gets its parent's presenter
methods, and its own methods stay out of the parent.

```ruby
class AdminSerializer < UserSerializer
  attribute :title

  presenter do
    def title
      "Sir #{name}"
    end
  end
end
```

A child copies its parent's blocks when it is created. A `presenter` block
added to the parent later does not reach existing children.
