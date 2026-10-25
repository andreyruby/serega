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
- A presenter of a shareable serializer reads attribute methods of the object
  directly. Other methods of the object that presenter methods call go
  through `method_missing` on each call, in every Ractor and thread. Call
  `make_shareable!` only for serializers used in other Ractors.
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
