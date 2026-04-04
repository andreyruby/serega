# Plugin :explicit_many_option

Makes the `:many` option required on every attribute that uses `:serializer`, and raises an error if it is omitted.

## When to use

- Your team wants relationship cardinality (`many: true` / `many: false`) declared explicitly in every serializer.
- You want to avoid silent reliance on Serega's Enumerable detection to determine whether a relationship is a collection.
- A code review standard requires all relationships to be unambiguous.

## Setup

```ruby
class AppSerializer < Serega
  plugin :explicit_many_option
end

class PostSerializer < AppSerializer
  attribute :user,     serializer: UserSerializer,    many: false
  attribute :comments, serializer: CommentSerializer, many: true
end
```

Defining an attribute with `:serializer` but without `:many` will raise a `SeregaError` at class definition time.

Attributes without `:serializer` are not affected.

---

**Next:** back to [Plugin index](README.md)
