# Selecting Fields

All attributes are serialized by default, except attributes defined with
`hide: true`. Three options change that:

- `:only` — serializes only the listed attributes;
- `:except` — skips the listed attributes;
- `:with` — adds hidden attributes.

```ruby
class UserSerializer < Serega
  attribute :username
  attribute :first_name
  attribute :email, hide: true
  attribute :friends, serializer: UserSerializer, hide: true
end

UserSerializer.to_h(bruce)
# => {username: "batman", first_name: "Bruce"}

UserSerializer.to_h(bruce, only: :username)
# => {username: "batman"}

UserSerializer.to_h(bruce, except: :first_name)
# => {username: "batman"}

UserSerializer.to_h(bruce, with: :email)
# => {username: "batman", first_name: "Bruce", email: "bruce@wayne.com"}
```

## Nested fields

Select fields of relations with a Hash. Fields are Symbols, Strings, Arrays,
Hashes or their combinations.

```ruby
UserSerializer.to_h(bruce, only: [:username, {friends: :email}])
# => {username: "batman", friends: [{email: "alfred@wayne.com"}]}

UserSerializer.to_h(bruce, with: {friends: :email})
# => {
#   username: "batman", first_name: "Bruce",
#   friends: [{username: "alfred", first_name: "Alfred", email: "alfred@wayne.com"}]
# }

UserSerializer.to_h(bruce, with: :friends, except: {friends: :first_name})
# => {username: "batman", first_name: "Bruce", friends: [{username: "alfred"}]}
```

A relation listed in `:only` without nested fields serializes its default
fields.

## Combining options

The options combine at each level: the root serializer and every relation
read their own part of `:only`, `:except` and `:with`.

When options name the same field, `:except` wins. `:only` and `:with` both
show the fields they name, hidden fields too:

```ruby
UserSerializer.to_h(bruce, only: [:username, :email], except: :email)
# => {username: "batman"}

UserSerializer.to_h(bruce, only: :username, with: :email)
# => {username: "batman", email: "bruce@wayne.com"}
```

`:only` hides the other fields of a level when it names a field of that level
without nested fields, or when `:except` and `:with` name no fields of that
level. Otherwise the level starts with its default fields, and a relation in
`:only` only selects the fields of that relation. Thus `:only` and `:with` on
one level equal one `:only` with the fields of both, when `:only` names a
field of that level without nested fields.

Each level can use its own option. The Result column lists the serialized
fields:

| Root | Friends | Fields | Result |
|---|---|---|---|
| only | except | `only: [:username, :friends], except: {friends: :first_name}` | username, friends(username) |
| only | with | `only: [:email, :friends], with: {friends: :email}` | email, friends(username, first_name, email) |
| except | only | `except: :first_name, only: {friends: :email}` | username, friends(email) |
| except | with | `except: :first_name, with: {friends: :email}` | username, friends(username, first_name, email) |
| with | only | `with: :email, only: {friends: :username}` | username, first_name, email, friends(username) |
| with | except | `with: :friends, except: {friends: :first_name}` | username, first_name, friends(username) |
| only | only | `only: {friends: :username}` | friends(username) |
| default | only | `with: :friends, only: {friends: :username}` | username, first_name, friends(username) |

## Fields from a request

Fields can be one String, with nested fields in parentheses. This fits query
parameters like `GET /users?fields=username,friends(username,email)`.

```ruby
UserSerializer.to_h(bruce, only: "username,friends(username,email)")
# => {username: "batman", friends: [{username: "alfred", email: "alfred@wayne.com"}]}

UserSerializer.to_h(users, only: params[:fields]) # all default fields when params[:fields] is nil
```

## Presets

A preset saves `:only`, `:with` and `:except` under a name, at any depth. The
`:preset` option selects its fields, so a client sends a short name instead of
a long list of fields.

```ruby
class UserSerializer < Serega
  attribute :username
  attribute :first_name
  attribute :email, hide: true
  attribute :friends, serializer: UserSerializer, hide: true

  preset :card, only: [:username, {friends: :username}]
  preset :profile, preset: :card, with: :email
end

UserSerializer.to_h(bruce, preset: :card)
# => {username: "batman", friends: [{username: "alfred"}]}

UserSerializer.to_h(bruce, preset: :profile)
# => {username: "batman", email: "bruce@wayne.com", friends: [{username: "alfred"}]}
```

- `preset:` in a preset definition names presets defined earlier. Their
  fields merge in when the preset is used.
- A preset with the name of an existing preset replaces it, also in the
  presets that include it.
- Subclasses inherit the presets, and can redefine them without changing the
  parent serializer.
- `preset:` in a serialization takes a name or an Array of names. An
  undefined preset raises `Serega::PresetNotExist`.
- A preset is checked when it is defined: its name, the presets it includes,
  that presets do not include each other, and the attributes it names. An
  unknown attribute raises `Serega::AttributeNotExist`:
  `Preset :card names not existing attributes: nickname`. The
  nested fields of a relation with a serializer name or a Proc are not
  checked then, so that serializer can be defined later. They are checked
  with the options of the call, like other fields.

### Presets with other options

Each option of the call merges with the option of the same name of the
presets. The result is the same as writing the merged options by hand, so
the rules of [Combining options](#combining-options) apply. `:only` and
`:with` add fields to a preset, and `:except` removes them:

```ruby
UserSerializer.to_h(bruce, preset: :card, only: {friends: :first_name})
# => {username: "batman", friends: [{username: "alfred", first_name: "Alfred"}]}

UserSerializer.to_h(bruce, preset: :card, except: :friends)
# => {username: "batman"}

UserSerializer.to_h(bruce, preset: [:card, :profile], with: :first_name)
```

Options name only attributes: `with: {friends: :card}` names an attribute
`card` of the friends.

### Preset on a relation

`preset:` on a relation names presets of the relation serializer. The
relation serializes the fields of these presets by default. The relation
serializer owns the list of fields: each parent names it once, and a change
to the preset changes every parent.

```ruby
class PostSerializer < Serega
  attribute :id
  attribute :title
  attribute :body

  preset :summary, only: [:id, :title]
end

class UserSerializer < Serega
  attribute :username
  attribute :posts, serializer: PostSerializer, many: true, preset: :summary

  preset :card, only: [:username, :posts]
end

UserSerializer.to_h(bruce)
# => {username: "batman", posts: [{id: 1, title: "Gotham at night"}]}

PostSerializer.to_h(post)
# => {id: 1, title: "Gotham at night", body: "Patrol notes"}
```

The options of the call for the relation merge with the preset, like
[Presets with other options](#presets-with-other-options):

| Call | Fields of `posts` |
|---|---|
| `to_h(bruce)` | `id`, `title` |
| `to_h(bruce, only: :posts)` | `id`, `title` |
| `to_h(bruce, preset: :card)` | `id`, `title` |
| `to_h(bruce, with: {posts: :body})` | `id`, `title`, `body` |
| `to_h(bruce, except: {posts: :title})` | `id` |
| `to_h(bruce, only: {posts: :id})` | `id`, `title`: `:only` adds fields to the preset |
| `to_h(bruce, except: :posts)` | `posts` is not serialized |

An option that names the relation without nested fields keeps the preset.
`:except` with nested fields removes only these fields, and the relation
stays:

```ruby
class CommentSerializer < Serega
  attribute :text
  attribute :user, serializer: UserSerializer
end

CommentSerializer.to_h(comment, except: {user: :posts})
# => {text: "Nice", user: {username: "batman"}}
```

- `preset:` takes a name or an Array of names, like the option of a call.
- A relation needs `:serializer` or a block. `preset:` without them raises
  `Serega::SeregaError`.
- When `:serializer` is a class, an undefined preset raises
  `Serega::PresetNotExist` when the attribute is defined. With a serializer
  name, a Proc or a block, it raises when the relation is first serialized.

### Field selection options of a relation

`:only`, `:with` and `:except` on a relation select the fields of the
relation by default, like the same options of a call. Use them for a list of
fields that only this relation needs. A list that several relations or calls
use belongs in a preset of the relation serializer.

```ruby
class UserSerializer < Serega
  attribute :username
  attribute :posts, serializer: PostSerializer, many: true, only: [:id, :title]
  attribute :drafts, serializer: PostSerializer, many: true, preset: :summary, with: :body
end

UserSerializer.to_h(bruce)
# => {username: "batman", posts: [{id: 1, title: "Gotham at night"}],
#     drafts: [{id: 2, title: "Arkham", body: "Draft notes"}]}
```

The relation presets, the options of the relation and the options of the
call merge, with the rules of [Combining options](#combining-options):
`to_h(bruce, with: {posts: :body})` adds `body` to the posts.

When `:serializer` is a class, an unknown field raises
`Serega::AttributeNotExist` when the attribute is defined:
`Relation :posts names not existing attributes: subtitle`. With a serializer
name, a Proc or a block, it raises when the relation is first serialized.

### When to use a preset

| Need | Use |
|---|---|
| A field is serialized only on request | [`hide: true`](attributes.md#hidden-attributes) |
| A relation serializes the same fields in every response | [`preset:` on the relation](#preset-on-a-relation) |
| Only one relation needs its list of fields | [Options on the relation](#field-selection-options-of-a-relation) |
| A client or an endpoint chooses the fields | `preset:`, `:only`, `:with` or `:except` in the call |
| The fields have other values or logic, not only fewer fields | Another serializer |

## Unknown fields

An unknown field raises `Serega::AttributeNotExist`. Its `#serializer` and
`#attributes` methods return the serializer and the unknown fields.

```ruby
UserSerializer.to_h(bruce, only: [:nickname, {friends: :age}])
# => Serega::AttributeNotExist: Not existing attributes: nickname, friends(age)
```

`check_selection: false` skips unknown fields:

```ruby
UserSerializer.to_h(bruce, only: [:username, :nickname], check_selection: false)
# => {username: "batman"}
```

## Hiding by default

`config.hide_by_default = true` hides every attribute that has no
`hide: false` option. `config.hide_by_default = :auto` hides attributes that
need [preloads](preloads.md) or [batch loaders](batch-loading.md), so clients
request expensive fields explicitly.

```ruby
class UserSerializer < Serega
  config.hide_by_default = true

  attribute :username
  attribute :first_name, hide: false
end

UserSerializer.to_h(bruce) # => {first_name: "Bruce"}
```
