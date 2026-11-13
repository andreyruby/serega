# Conditional Attributes

`:if` and `:unless` skip an attribute depending on the serialized object.
`:if_value` and `:unless_value` skip it depending on its value.

```ruby
class UserSerializer < Serega
  attribute :email, if: :active?                                    # user.active?
  attribute :phone, if: proc { |user, ctx| ctx[:admin] }
  attribute :role, unless: proc { |user, ctx:| ctx[:public] }
  attribute :nickname, if_value: proc { |nickname| !nickname.nil? }
  attribute :rating, unless_value: :zero?                           # rating.zero?
end

UserSerializer.to_h(user, context: {admin: true})
# => {email: "bruce@wayne.com", phone: "555-0100", role: "admin", rating: 5}
```

## Conditions

A condition is one of:

- a method name, called on the object (`:if`, `:unless`) or on the value
  (`:if_value`, `:unless_value`);
- a callable that receives the object or the value, and the
  [context](context.md) as a second parameter or as the `:ctx` keyword.

```ruby
attribute :email, if: proc { |user, ctx| user == ctx[:current_user] }
attribute :email, if: EmailPolicy.method(:visible?) # EmailPolicy.visible?(user)
attribute :email, if_value: proc { |email, ctx| ctx[:show_emails] }
```

## Order of checks

`:if` and `:unless` are checked before the value is found, so a skipped
attribute does not compute its value. `:if_value` and `:unless_value` are
checked after.

`:unless` is checked only when `:if` passes, and `:unless_value` only when
`:if_value` passes.

## Relations

`:if` and `:unless` skip a relation before its related objects are
serialized. `:if_value` and `:unless_value` check the serialized relation
value: a Hash, an Array of Hashes or `nil`, or `Struct` and `Data` objects with
`.to_struct` and `.to_data`. The related objects are serialized before this
check, thus prefer `:if` and `:unless` when the object decides.

```ruby
class UserSerializer < Serega
  attribute :posts, serializer: PostSerializer, many: true, unless_value: :empty?
  attribute :avatar, serializer: AvatarSerializer, unless_value: :nil?
end

UserSerializer.to_h(user) # a user without posts and avatar
# => {}
```

## Skipped attributes in results

`.to_h` omits skipped attributes. `.to_struct` and `.to_data` return `nil` for
them, so all objects serialized with the same fields have the same members.

```ruby
UserSerializer.to_h(user, context: {public: true})
# => {email: "bruce@wayne.com", rating: 5}

UserSerializer.to_struct(user, context: {public: true})
# => #<struct email="bruce@wayne.com", phone=nil, role=nil, nickname=nil, rating=5>
```

## Errors

An error raised by a condition names the condition and the line where the
attribute is defined:

```text
(when checking the :if condition of the 'email' attribute in UserSerializer, app/serializers/user_serializer.rb:4)
```

To hide an attribute unless a client requests it, use `hide: true`, see
[Selecting fields](selecting-fields.md).
