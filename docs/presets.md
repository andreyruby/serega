# Presets

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

UserSerializer.to_h(gru, preset: :card)
# => {username: "gru", friends: [{username: "lucy"}]}

UserSerializer.to_h(gru, preset: :profile)
# => {username: "gru", email: "gru@example.com", friends: [{username: "lucy"}]}
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

## Table of Contents

<!-- toc -->

- [Presets with other options](#presets-with-other-options)
- [Preset on a relation](#preset-on-a-relation)
- [Field selection options of a relation](#field-selection-options-of-a-relation)
- [When to use a preset](#when-to-use-a-preset)

<!-- tocstop -->

## Presets with other options

Each option of the call merges with the option of the same name of the
presets. The result is the same as writing the merged options by hand, so
the rules of [Combining options](selecting-fields.md#combining-options) apply. `:only` and
`:with` add fields to a preset, and `:except` removes them:

```ruby
UserSerializer.to_h(gru, preset: :card, only: {friends: :first_name})
# => {username: "gru", friends: [{username: "lucy", first_name: "Lucy"}]}

UserSerializer.to_h(gru, preset: :card, except: :friends)
# => {username: "gru"}

UserSerializer.to_h(gru, preset: [:card, :profile], with: :first_name)
```

Options name only attributes: `with: {friends: :card}` names an attribute
`card` of the friends.

## Preset on a relation

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

UserSerializer.to_h(gru)
# => {username: "gru", posts: [{id: 1, title: "Stealing the Moon"}]}

PostSerializer.to_h(post)
# => {id: 1, title: "Stealing the Moon", body: "Shrink ray plans"}
```

The options of the call for the relation merge with the preset, like
[Presets with other options](#presets-with-other-options):

| Call | Fields of `posts` |
|---|---|
| `to_h(gru)` | `id`, `title` |
| `to_h(gru, only: :posts)` | `id`, `title` |
| `to_h(gru, preset: :card)` | `id`, `title` |
| `to_h(gru, with: {posts: :body})` | `id`, `title`, `body` |
| `to_h(gru, except: {posts: :title})` | `id` |
| `to_h(gru, only: {posts: :id})` | `id`, `title`: `:only` adds fields to the preset |
| `to_h(gru, except: :posts)` | `posts` is not serialized |

An option that names the relation without nested fields keeps the preset.
`:except` with nested fields removes only these fields, and the relation
stays:

```ruby
class CommentSerializer < Serega
  attribute :text
  attribute :user, serializer: UserSerializer
end

CommentSerializer.to_h(comment, except: {user: :posts})
# => {text: "Nice", user: {username: "gru"}}
```

- `preset:` takes a name or an Array of names, like the option of a call.
- A relation needs `:serializer` or a block. `preset:` without them raises
  `Serega::SeregaError`.
- When `:serializer` is a class, an undefined preset raises
  `Serega::PresetNotExist` when the attribute is defined. With a serializer
  name, a Proc or a block, it raises when the relation is first serialized.

## Field selection options of a relation

`:only`, `:with` and `:except` on a relation select the fields of the
relation by default, like the same options of a call. They fit a list of
fields that only this relation needs; a list that several relations or calls
use fits a preset of the relation serializer.

```ruby
class UserSerializer < Serega
  attribute :username
  attribute :posts, serializer: PostSerializer, many: true, only: [:id, :title]
  attribute :drafts, serializer: PostSerializer, many: true, preset: :summary, with: :body
end

UserSerializer.to_h(gru)
# => {username: "gru", posts: [{id: 1, title: "Stealing the Moon"}],
#     drafts: [{id: 2, title: "Arkham", body: "Draft notes"}]}
```

The relation presets, the options of the relation and the options of the
call merge, with the rules of [Combining options](selecting-fields.md#combining-options):
`to_h(gru, with: {posts: :body})` adds `body` to the posts.

When `:serializer` is a class, an unknown field raises
`Serega::AttributeNotExist` when the attribute is defined:
`Relation :posts names not existing attributes: subtitle`. With a serializer
name, a Proc or a block, it raises when the relation is first serialized.

## When to use a preset

One way to choose between the options:

| Need | Option |
|---|---|
| A field is serialized only on request | [`hide: true`](attributes.md#hidden-attributes) |
| A relation serializes the same fields in every response | [`preset:` on the relation](#preset-on-a-relation) |
| Only one relation needs its list of fields | [Options on the relation](#field-selection-options-of-a-relation) |
| A client or an endpoint chooses the fields | `preset:`, `:only`, `:with` or `:except` in the call |
| The fields have other values or logic, not only fewer fields | Another serializer |
