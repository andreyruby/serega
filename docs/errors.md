# Errors

| Error | Raised when |
|---|---|
| `Serega::SeregaError` | Invalid definitions, options or changes to locked serializers. Base class of other errors |
| `Serega::AttributeNotExist` | `:only`, `:except` or `:with` lists an unknown field |
| `Serega::DepthLimitError` | Fields nest deeper than [`config.depth_limit`][depth_limit] allows |

`Serega::AttributeNotExist#serializer` returns the serializer and `#attributes`
returns the unknown fields. See [Selecting fields](selecting-fields.md#unknown-fields).

## Errors in attributes

Serega keeps the class of an error raised while serializing an attribute, and
adds the attribute, the serializer and the line where the attribute is
defined to its message:

```text
NoMethodError: undefined method 'city' for nil
(when serializing the 'city' attribute in UserSerializer, app/serializers/user_serializer.rb:5)
```

The backtrace has a line at the attribute too, below the line that raised:

```text
app/models/user.rb:12:in 'User#address'
app/serializers/user_serializer.rb:5:in 'attribute :city of UserSerializer'
(serega generated code):20:in 'call'
```

Errors raised by [conditions](conditional-attributes.md#errors) name the
condition too.

[depth_limit]: configuration.md#depth-limit
