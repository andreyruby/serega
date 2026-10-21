# Serega

<!-- TODO: logo (SVG, light and dark variants)
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark.svg">
    <img src="assets/logo.svg" alt="Serega" width="240">
  </picture>
</p>
-->

**Serialize exactly what was asked. Load exactly what is needed.**

[![Gem Version](https://badge.fury.io/rb/serega.svg)](https://badge.fury.io/rb/serega)
[![GitHub Actions][build-badge]][build]
![Coverage 100%](https://img.shields.io/badge/coverage-100%25-brightgreen)
![Zero dependencies](https://img.shields.io/badge/dependencies-0-brightgreen)
![Ruby >= 3.3](https://img.shields.io/badge/ruby-%3E%3D%203.3-red)

Serega is a Ruby serializer that turns your objects into Hashes ready for JSON.
Clients choose the fields they need, and Serega loads only the data those
fields use — in a few queries, with no N+1.

- ⚡ **Fast** — serialization code is generated per field selection and cached.
  [See benchmarks](#benchmarks).
- 🎯 **Clients choose fields** — `?fields=name,posts(title)` works out of the
  box, nested at any depth.
- 🧺 **No N+1** — associations are preloaded and batch loaders run once per
  relation, only for the requested fields.
- 🪶 **No dependencies** — plain Ruby, works with Rails, Hanami, Roda, Sinatra
  or no framework at all.

## Show me

```ruby
class AppSerializer < Serega
  plugin :activerecord_preloads   # preloads associations used by requested fields
  plugin :string_modifiers        # accepts fields as "name,posts(title)"
  config.auto_preload = true
  config.hide_by_default = :auto  # fields that need extra queries are sent on request
end

class UserSerializer < AppSerializer
  attribute :name
  attribute :posts, serializer: "PostSerializer"
end

class PostSerializer < AppSerializer
  batch :comments_count, ->(posts) { Comment.where(post: posts).group(:post_id).count }

  attribute :title
  attribute :comments_count, batch: true
end

UserSerializer.to_h(User.all)
# => [{name: "Bruce Wayne"}, ...]                                    1 query

UserSerializer.to_h(User.all, only: "name,posts(title,comments_count)")
# => [{name: "Bruce Wayne", posts: [{title: "Gotham at night", comments_count: 12}, ...]}, ...]
#                                                                    3 queries, for any number of users
```

## Installation

```sh
bundle add serega
```

## Quick start

Define a base serializer with the plugins and config your app uses. Every
serializer inherits them.

```ruby
# app/serializers/app_serializer.rb
class AppSerializer < Serega
  plugin :activerecord_preloads
  plugin :string_modifiers
  config.auto_preload = true
end

# app/serializers/user_serializer.rb
class UserSerializer < AppSerializer
  attribute :id
  attribute :name
  attribute :email, value: proc { |user, ctx| user.email if user == ctx[:current_user] }
  attribute :avatar_url, hide: true
end

# app/controllers/users_controller.rb
class UsersController < ApplicationController
  def index
    users = UserSerializer.to_h(
      User.all,
      only: params[:fields],              # "id,name" from GET /users?fields=id,name
      context: {current_user: current_user}
    )

    render json: users
  end
end
```

## Benchmarks

Serializations of preloaded ActiveRecord records to JSON strings, per second,
more is better:

| Serializer               |    1 post | 100 posts | 100 posts with relations | `only:` | `except:` |
|--------------------------|----------:|----------:|-------------------------:|--------:|----------:|
| **serega**               | 2,028,685 |    25,885 |                    2,546 |   5,074 |     3,744 |
| oj_serializers           |   788,772 |    21,072 |                    2,189 |       — |         — |
| panko_serializer         |   553,027 |    17,035 |                    1,683 |   3,932 |     2,611 |
| alba                     |   788,318 |    14,119 |                    1,300 |       — |         — |
| blueprinter              |   610,456 |     9,014 |                      896 |       — |         — |
| active_model_serializers |    67,752 |     1,029 |                       79 |     120 |         — |
| *hand-written Hash*      | 2,329,852 |    26,341 |                    2,412 |   4,810 |     3,498 |

Hashes, the details of each case and how to run them:
[benchmarks/README.md](benchmarks/README.md).

## Features

### Select fields

`only`, `except` and `with` accept Symbols, Arrays, Hashes or a string like
`"name,posts(title)"`. Unknown fields raise `Serega::AttributeNotExist`.

```ruby
UserSerializer.to_h(user, only: [:name, {posts: [:title]}])
UserSerializer.to_h(user, except: :email)
UserSerializer.to_h(user, with: :avatar_url)  # adds hidden fields
```

→ [Selecting fields guide](docs/selecting-fields.md)

### Batch loading

Load data for all serialized objects with one call.

```ruby
class UserSerializer < AppSerializer
  batch :followers_count, ->(users) { Follow.where(user: users).group(:user_id).count }

  attribute :followers_count, batch: true
end
```

→ [Batch loading guide](docs/batch-loading.md) ·
[Preloads guide](docs/preloads.md)

### Formatters

Format dates, money and other values the same way everywhere.

```ruby
class AppSerializer < Serega
  formatter :iso8601, [:iso8601, 3], allow_nil: true
end

class UserSerializer < AppSerializer
  attribute :created_at, format: :iso8601
end
```

→ [Formatters guide](docs/formatters.md)

### Hashes, Structs and Data

Serialize Hash records, and get results as `Struct` or `Data` objects.

```ruby
class EventSerializer < Serega
  attribute :title, hash_access: true  # reads event[:title]
end

UserSerializer.to_h(user)      # => {name: "Bruce Wayne"}
UserSerializer.to_struct(user) # => #<struct name="Bruce Wayne">
UserSerializer.to_data(user)   # => #<data name="Bruce Wayne">
```

→ [Hash records guide](docs/hash-records.md) ·
[Serializing guide](docs/serializing.md)

### Ractors

Serialize in parallel Ractors.

```ruby
class UserSerializer < Serega
  attribute :name
  make_shareable!
end

Ractor.new(user) { |user| UserSerializer.to_h(user) }.value
```

→ [Ractors guide](docs/ractors.md)

### And more

- [Attributes](docs/attributes.md) — all attribute options, relations and nested serializers
- [Conditional attributes](docs/conditional-attributes.md) — `if:`, `unless:`, `if_value:`, `unless_value:`
- [Context](docs/context.md) — pass `current_user` and other request data
- [Presenter](docs/presenter.md) — write computed attributes as methods
- [Prepare initial objects](docs/prepare-initial-objects.md) — serialize records by ids
- [Configuration](docs/configuration.md) — all config options
- [Plugins](docs/plugins.md) — `root`, `metadata`, `camel_case`, `depth_limit` and others

## Documentation

- 📋 [Cheatsheet](CHEATSHEET.md) — every option on one page
- 📚 [Guides](docs/README.md) — each feature in depth
- 🔎 [API docs](https://rubydoc.info/gems/serega) — YARD reference
- 📝 [Changelog](CHANGELOG.md)

## Development

```sh
bundle install
bundle exec rake  # tests and linter
bin/console       # irb with serega loaded
```

Releasing: [RELEASE.md](RELEASE.md).

## Contributing

Bug reports, pull requests and ideas are welcome!

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).

[build-badge]: https://github.com/aglushkov/serega/actions/workflows/main.yml/badge.svg?event=push
[build]: https://github.com/aglushkov/serega/actions/workflows/main.yml
