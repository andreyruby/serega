# Ractors

End a serializer definition with `make_shareable!` to serialize in other
Ractors. Define serializers in the main Ractor, then serialize anywhere:

```ruby
class UserSerializer < Serega
  attribute :name
  make_shareable!
end

Ractor.new(user) { |user| UserSerializer.to_h(user) }.value
# => {name: "Ann"}
```

- Call `make_shareable!` in relation serializers too. Nested serializers
  defined with a block become shareable with their parent.
- A shareable serializer can not be changed.
- A shareable serializer with a presenter is slower when presenter methods
  call methods of the object that are not attributes. With 20 objects of 10
  attributes, 2 of them presenter methods that call 2 such methods each,
  serialization takes 25.5 µs instead of 11.7 µs, in every Ractor and thread.
  The same attributes with `:value` options take 6.3 µs, 4 times less, with or
  without `make_shareable!`. These are microseconds, thus they matter little
  in a request that takes milliseconds. Prefer `:value` options in serializers
  used in other Ractors, and call `make_shareable!` only for those.
- Each Ractor builds and caches its own serialization plans.
- On a Ruby without Ractors, for example TruffleRuby, `make_shareable!` only
  locks the serializer.

## What can be shared

`make_shareable!` deep-freezes the serializer definitions with
`Ractor.make_shareable`: attribute options, formatters, batch loaders,
`preload_with` and `prepare_initial_objects` handlers.

- A block given to `attribute`, `batch`, `formatter` or another definition is
  shareable when it is written in the serializer class and refers only to
  shareable values.
- A callable object that changes its own state, for example a formatter that
  caches values in an instance variable, raises `FrozenError` when it
  serializes.

A serializer with a definition that can not be shared serializes in the main
Ractor only. In other Ractors it raises `Serega::SeregaError` with the reason:

```ruby
class UserSerializer < Serega
  suffix = +"!"
  attribute :greeting, value: proc { |user| user.name + suffix }
  make_shareable!
end

UserSerializer.to_h(user) # => {greeting: "Ann!"}

Ractor.new(user) { |user| UserSerializer.to_h(user) }.value
# => Serega::SeregaError: Attribute :greeting of UserSerializer can not be
#    shared between Ractors (app/serializers/user_serializer.rb:3): cannot make
#    a shareable Proc because it can refer unshareable object "!" from variable
#    'suffix'
```
