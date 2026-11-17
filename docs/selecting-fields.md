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

UserSerializer.to_h(gru)
# => {username: "gru", first_name: "Felonious"}

UserSerializer.to_h(gru, only: :username)
# => {username: "gru"}

UserSerializer.to_h(gru, except: :first_name)
# => {username: "gru"}

UserSerializer.to_h(gru, with: :email)
# => {username: "gru", first_name: "Felonious", email: "gru@example.com"}
```

## Table of Contents

<!-- toc -->

- [Nested fields](#nested-fields)
- [Combining options](#combining-options)
- [Fields from a request](#fields-from-a-request)
- [Unknown fields](#unknown-fields)
- [Hiding by default](#hiding-by-default)

<!-- tocstop -->

## Nested fields

Select fields of relations with a Hash. Fields are Symbols, Strings, Arrays,
Hashes or their combinations.

```ruby
UserSerializer.to_h(gru, only: [:username, {friends: :email}])
# => {username: "gru", friends: [{email: "lucy@example.com"}]}

UserSerializer.to_h(gru, with: {friends: :email})
# => {
#   username: "gru", first_name: "Felonious",
#   friends: [{username: "lucy", first_name: "Lucy", email: "lucy@example.com"}]
# }

UserSerializer.to_h(gru, with: :friends, except: {friends: :first_name})
# => {username: "gru", first_name: "Felonious", friends: [{username: "lucy"}]}
```

A relation listed in `:only` without nested fields serializes its default
fields.

## Combining options

The options combine at each level: the root serializer and every relation
read their own part of `:only`, `:except` and `:with`.

When options name the same field, `:except` wins. `:only` and `:with` both
show the fields they name, hidden fields too:

```ruby
UserSerializer.to_h(gru, only: [:username, :email], except: :email)
# => {username: "gru"}

UserSerializer.to_h(gru, only: :username, with: :email)
# => {username: "gru", email: "gru@example.com"}
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
UserSerializer.to_h(gru, only: "username,friends(username,email)")
# => {username: "gru", friends: [{username: "lucy", email: "lucy@example.com"}]}

UserSerializer.to_h(users, only: params[:fields]) # all default fields when params[:fields] is nil
```

Public APIs select fields from the root of the response the same way, also
inside a list wrapper: Google APIs with
[`fields=items(id,snippet(title))`](https://developers.google.com/youtube/v3/getting-started),
Stripe with [`expand[]=data.customer`](https://docs.stripe.com/expand) and
Mailchimp with
[`fields=lists.name,lists.id`](https://mailchimp.com/developer/marketing/docs/methods-parameters/).

## Unknown fields

An unknown field raises `Serega::AttributeNotExist`. Its `#serializer` and
`#attributes` methods return the serializer and the unknown fields.

```ruby
UserSerializer.to_h(gru, only: [:nickname, {friends: :age}])
# => Serega::AttributeNotExist: Not existing attributes: nickname, friends(age)
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

UserSerializer.to_h(gru) # => {first_name: "Felonious"}
```

With `:auto` and the serializers of [Preloads](preloads.md), a request without
the expensive fields loads nothing:

```ruby
class AppSerializer < Serega
  plugin :activerecord_preloads

  configure do |config|
    config.auto_preload = true
    config.hide_by_default = :auto
  end
end

UserSerializer.to_h(users)
# => [{name: "Felonious"}, ...], no preloads

UserSerializer.to_h(users, with: [:followers_count, {albums: :downloads_count}])
# preloads user_stats and albums for users, downloads for albums
```
