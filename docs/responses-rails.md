# Responses in Rails

This guide adds Rails and ActiveRecord to
[Response Serializers](responses.md): it uses `Serializers::Base`,
`Serializers::Meta` and `Serializers::Response` from there. Like that guide,
it is an example: take the parts that fit your app.

## Table of Contents

<!-- toc -->

- [ActiveRecord](#activerecord)
   - [Preloads instead of `includes`](#preloads-instead-of-includes)
   - [Batch loading from a cache](#batch-loading-from-a-cache)
   - [Paging with Kaminari](#paging-with-kaminari)
- [Controllers](#controllers)
- [A common context](#a-common-context)
- [Flash messages](#flash-messages)
- [Validation errors](#validation-errors)

<!-- tocstop -->

## ActiveRecord

### Preloads instead of `includes`

`plugin :activerecord_preloads` with `config.auto_preload = true` preloads the
relations of the serialized fields, so the query needs no `includes` or
`preload`: the serializer knows which relations the client requested.

```ruby
module Serializers
  class Base < Serega
    plugin :activerecord_preloads

    configure do |config|
      config.auto_preload = true
      config.hide_by_default = :auto
    end
  end

  class Post < Base
    attribute :id
    attribute :title
  end

  class User < Base
    attribute :id
    attribute :name
    attribute :posts, serializer: Post, many: true # preloads :posts
  end
end

users = User.order(:id).limit(20)
USERS_SERIALIZER.to_json(users)
# SELECT "users".* FROM "users" ORDER BY "users"."id" ASC LIMIT 20
# => {"data":[{"id":1,"name":"Felonious Gru"}],"meta":{"version":"1"}}

USERS_SERIALIZER.to_json(users, with: "data(posts)") # users are loaded already
# SELECT "posts".* FROM "posts" WHERE "posts"."user_id" IN (1, 2, ...)
# => {"data":[{"id":1,"name":"Felonious Gru","posts":[{"id":1,"title":"Freedonia"}]}],"meta":{"version":"1"}}
```

`posts` has a preload, so `hide_by_default = :auto` hides it until a client
requests it. With `includes(:posts)` in the query, the first call loads the
posts it doesn't serialize. See [Preloads](preloads.md).

### Batch loading from a cache

A value that is not a relation, for example a value in a cache, loads with a
[batch loader](batch-loading.md): one cache read for all users, not one per
user.

```ruby
module Serializers
  class User < Base
    # One read_multi for all users; returns {user_id => value}
    batch :last_seen_at, lambda { |users|
      keys = users.to_h { |user| ["users/#{user.id}/last_seen_at", user.id] }
      Rails.cache.read_multi(*keys.keys).transform_keys(keys)
    }

    attribute :id
    attribute :name
    attribute :last_seen_at, batch: true
  end
end
```

`last_seen_at` has a batch loader, so it is hidden too:
`with: "data(last_seen_at)"` requests it, and only then the cache is read.
`Rails.cache` stands for any ActiveSupport cache store; other caches need a
multi-get, such as Redis `MGET`.

### Paging with Kaminari

`Paging` serializes the Kaminari methods of a scope. `Meta` adds it only for
a scope paged with Kaminari: `.page` on a relation or
`Kaminari.paginate_array`. A record, an Array or a scope without `.page` skip
it, see [Conditional Attributes](conditional-attributes.md).

```ruby
module Serializers
  class Paging < Base
    attribute :page, method: :current_page
    attribute :per_page, method: :limit_value
    attribute :total_count
    attribute :total_pages
  end

  class Meta < Base
    attribute :version, const: "1"
    attribute :request_id, value: proc { |_object, ctx| ctx[:request_id] }, unless_value: :nil?

    attribute :paging, serializer: Paging, method: :itself, many: false, # the scope as one object
      if: proc { |object| object.is_a?(Kaminari::PageScopeMethods) }      # only Kaminari scopes
  end
end

users = User.order(:id).page(1).per(20)
USERS_SERIALIZER.to_json(users, only: "meta")
# => {"meta":{"version":"1","paging":{"page":1,"per_page":20,"total_count":1,"total_pages":1}}}
```

Without `many: false` on `paging`, Serega calls the methods of `Paging` on
each user and raises
`NoMethodError: undefined method 'current_page' for an instance of User`.
See [Why `many: false`](responses.md#why-many-false).

## Controllers

In this example, controllers keep the response serializers in constants and
render JSON with `json`, an `ApplicationController` method that adds the
[common context](#a-common-context):

```ruby
class UsersController < ApplicationController
  USER_SERIALIZER = Serializers::Response.one(Serializers::User)
  USERS_SERIALIZER = Serializers::Response.list(Serializers::User)

  def index
    users = User.order(:id).page(params[:page]).per(20)
    render json: json(USERS_SERIALIZER, users)
  end

  def show
    user = User.find(params[:id])
    render json: json(USER_SERIALIZER, user)
  end
end
```

## A common context

Most responses need the same [context](context.md): the current user, the
request id. This example builds it in one method of `ApplicationController`,
as a serializer has no access to the request. `json` serializes with it, and
with the fields the request [selects](responses.md#selecting-fields) in its `only`,
`with`, `except` and `preset` parameters:

```ruby
class ApplicationController < ActionController::API
  rescue_from Serega::AttributeNotExist, Serega::PresetNotExist do |error|
    render json: {errors: [{source: "fields", title: error.message}]}, status: :bad_request
  end

  private

  # The context of every response
  def serialization_context
    {
      request_id: request.request_id,
      current_user: proc { current_user } # found only when a serialized field reads it
    }
  end

  # JSON of the serializer with the fields of the request and the common
  # context; `context:` adds to it
  def json(serializer, object, context: {})
    serializer.to_json(
      object,
      only: params[:only],
      with: params[:with],
      except: params[:except],
      preset: params[:preset],
      context: serialization_context.merge(context)
    )
  end
end
```

`current_user: current_user` works too, but it finds the user for every
response. With a proc, a response finds the user only when a requested field
reads it, so a public response with no user-specific fields skips the lookup:

```ruby
module Serializers
  class User < Base
    attribute :id
    attribute :name
    attribute :editable, hide: true, value: proc { |user, ctx| user == ctx[:current_user].call }
  end
end

```

```text
GET /users
{"data":[{"id":1,"name":"Felonious Gru"},{"id":2,"name":"Lucy"}],"meta":{"version":"1","request_id":"f3a9"}}
The proc is not called, so the user is not found.

GET /users?with=data(editable)
{"data":[{"id":1,"name":"Felonious Gru","editable":true},{"id":2,"name":"Lucy","editable":false}],
 "meta":{"version":"1","request_id":"f3a9"}}

GET /users?only=data(nickname)
400 {"errors":[{"source":"fields","title":"Not existing attributes: data(nickname)"}]}
```

A `:value` proc runs once per object, so the proc runs once per user. Rails
apps usually memoize `current_user`, which keeps the lookup to one query; a
[batch loader](batch-loading.md#values-for-the-current-user) calls the proc
once per serialization. Where there is no request, as in a mailer, pass
`current_user: proc {}`, and the same serializers work.

## Flash messages

`notice` and `alert`, the names of Rails flash messages, can go to `meta` the
same way as `request_id`: pass them in the context, and add them to `Meta`.

```ruby
attribute :notice, value: proc { |_object, ctx| ctx[:notice] }, unless_value: :nil?
attribute :alert, value: proc { |_object, ctx| ctx[:alert] }, unless_value: :nil?
```

API-only apps have no flash, so the controller adds the messages itself:
`json(USERS_SERIALIZER, users, context: {notice: "Users imported"})`. Other
apps add them to `serialization_context`:
`notice: flash[:notice], alert: flash[:alert]`.

## Validation errors

This example renders validation errors as `{errors: [...]}`; give them the
shape your API uses. `ActiveModel::Errors#objects` returns
`ActiveModel::Error` objects, so a serializer reads them like any records.
Error serializers inherit `Serega` directly: they need none of the config and
plugins of `Base`.

```ruby
module Serializers
  class Error < Serega
    attribute :source, method: :attribute
    attribute :title, method: :message
  end

  # The errors of one record as one response
  class Errors < Serega
    config.many = false # one {errors:}, not one response per error
    attribute :errors, serializer: Error, method: :objects, many: true # ActiveModel::Error objects
  end
end
```

`create!` and `update!` raise `ActiveRecord::RecordInvalid` for an invalid
record. Here actions don't check for errors, and one handler in
`ApplicationController` renders the errors of every action:

```ruby
class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordInvalid do |error|
    errors = error.record.errors
    render json: Serializers::Errors.to_json(errors), status: :unprocessable_entity
  end
end

class UsersController < ApplicationController
  def create
    user = User.create!(user_params) # raises ActiveRecord::RecordInvalid for an invalid user
    render json: json(USER_SERIALIZER, user), status: :created
  end
end
```

```text
POST /users {"user":{"name":""}}
422 {"errors":[{"source":"name","title":"can't be blank"}]}
```

A serializer named `Serializers::User` lives in a file that your autoloader
maps to that name, for example `app/serializers/serializers/user.rb`.
