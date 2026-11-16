# Errors

| Error | Raised when |
|---|---|
| `Serega::SeregaError` | Invalid definitions, options or changes to locked serializers. Base class of other errors |
| `Serega::AttributeNotExist` | `:only`, `:except`, `:with` or a preset lists an unknown field |
| `Serega::PresetNotExist` | `:preset` names an undefined preset |
| `Serega::DepthLimitError` | Fields nest deeper than [`config.depth_limit`][depth_limit], or relations in a cycle |

`Serega::AttributeNotExist#serializer` returns the serializer and `#attributes`
returns the unknown fields. See [Selecting fields](selecting-fields.md#unknown-fields).

`Serega::PresetNotExist#serializer` returns the serializer and `#preset`
returns the name of the undefined preset. See [Presets](presets.md).

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

Errors raised by [conditions](conditional-attributes.md#finding-a-failing-condition) name the
condition too.

[depth_limit]: relations.md#limiting-nesting-depth
