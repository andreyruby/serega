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

## Conditions that load data

A condition runs once per object, thus a query inside it runs once per object
too. Load the data for all objects at once instead.

An association: [preload](preloads.md) it, and read it in `:if`.

```ruby
class UserSerializer < Serega
  plugin :activerecord_preloads

  attribute :email, preload: :privacy_setting, if: proc { |user| user.privacy_setting.public_email }
end

UserSerializer.to_h(users)
# SELECT * FROM privacy_settings WHERE user_id IN (1, 2)
# => [{email: "bruce@wayne.com"}, {}]
```

Other data: load it with a [batch loader](batch-loading.md), build `nil` in
`:value` for a hidden object, and skip `nil` with `:unless_value`.

```ruby
class UserSerializer < Serega
  batch :visible_user_ids, ->(users, ctx:) { ctx[:viewer].visible_users.where(id: users).pluck(:id).to_set }

  attribute :email, batch: {use: :visible_user_ids}, unless_value: :nil?,
    value: proc { |user, batches:| user.email if batches[:visible_user_ids].include?(user.id) }
end

UserSerializer.to_h(users, context: {viewer: current_user})
# SELECT id FROM users WHERE ... AND id IN (1, 2)
# => [{email: "bruce@wayne.com"}, {}]
```

The batch way skips the attribute for a `nil` email of a visible user too. A
relation works the same way: `:value` gives `nil` for a hidden object, and
`unless_value: :nil?` skips the relation.

## Skipped attributes in results

`.to_h` omits skipped attributes. `.to_struct` and `.to_data` return `nil` for
them, so all objects serialized with the same fields have the same members.

```ruby
UserSerializer.to_h(user, context: {public: true})
# => {email: "bruce@wayne.com", rating: 5}

UserSerializer.to_struct(user, context: {public: true})
# => #<struct email="bruce@wayne.com", phone=nil, role=nil, nickname=nil, rating=5>
```

## Leaving out nil values

`config.compact = true` leaves out every key with a `nil` value, as
`Hash#compact` does. Set it in a base serializer to compact whole responses,
nested serializers included:

```ruby
class AppSerializer < Serega
  config.compact = true
end

class UserSerializer < AppSerializer
  attribute :first_name
  attribute :nickname
  attribute :posts, serializer: PostSerializer, many: true
end

UserSerializer.to_h(user) # a user without a nickname and posts
# => {first_name: "Bruce", posts: []}
```

A nested serializer follows its own config: one without `compact` keeps its
`nil` values. Empty Strings, Arrays and Hashes stay, and `nil` items inside an
Array stay too. `.to_struct` and `.to_data` keep `nil` members.

## Errors

An error raised by a condition names the condition and the line where the
attribute is defined:

```text
(when checking the :if condition of the 'email' attribute in UserSerializer, app/serializers/user_serializer.rb:4)
```

To hide an attribute unless a client requests it, use `hide: true`, see
[Selecting fields](selecting-fields.md).
