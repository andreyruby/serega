# Plugin :presenter

Wraps each serialized object in a `Presenter` class defined inside the serializer; attribute methods are called on the presenter instead of the raw object.

## When to use

- Attribute logic involves combining or transforming multiple fields and you want to keep that logic out of the serializer class body.
- You prefer plain Ruby methods over inline procs for readability.
- Multiple attributes share helper logic that belongs together.

## Setup

```ruby
class UserSerializer < Serega
  plugin :presenter

  attribute :name
  attribute :address

  class Presenter
    def name
      [first_name, last_name].compact.join(" ")
    end

    def address
      [country, city, street].join(", ")
    end
  end
end
```

## How it works

When an object is serialized, it is wrapped in `UserSerializer::Presenter.new(object)`. The presenter inherits from `SimpleDelegator`, so any method not defined on the presenter is forwarded to the underlying object automatically.

On the first `method_missing` hit, the delegator method is defined on the presenter class to avoid repeated `method_missing` overhead on subsequent serializations.

Each serializer subclass gets its own `Presenter` subclass, so presenter methods defined in a parent serializer are inherited but can be overridden.

## Runnable example

`examples/presenter.rb`

---

**Next:** [depth_limit](depth_limit.md)
