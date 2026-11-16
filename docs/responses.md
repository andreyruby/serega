# Response Serializers

A response serializer wraps the records of an API response with `data` and
adds `meta`, such as paging. It is a plain serializer with a `data` and a
`meta` attribute, so it uses the attribute options you already know, and
clients select its fields from the root.

```json
{
  "data": [{"id": 1, "name": "Bruce Wayne"}],
  "meta": {"version": "1", "paging": {"page": 1, "per_page": 20, "total_count": 1, "total_pages": 1}}
}
```

This guide is an example: one of many ways to structure API responses. Take
the parts that fit your API and change the rest.

The steps work in any Ruby app. The sections after them add what depends on
the records and the framework: ActiveRecord preloads and paging, batch loading
for other records, and a Rails controller.

Response serializers replace the [root and metadata plugins](root-and-metadata.md),
see [Migrating from the Root and Metadata Plugins](migrating-from-root-and-metadata.md).

## Table of Contents

<!-- toc -->

- [Step by step](#step-by-step)
   - [1. Serialize the records](#1-serialize-the-records)
   - [2. Describe `meta`](#2-describe-meta)
   - [3. Add a common response shape](#3-add-a-common-response-shape)
   - [4. Serialize responses](#4-serialize-responses)
- [ActiveRecord](#activerecord)
   - [Preloads instead of `includes`](#preloads-instead-of-includes)
   - [Batch loading from a cache](#batch-loading-from-a-cache)
   - [Paging with Kaminari](#paging-with-kaminari)
- [Without ActiveRecord](#without-activerecord)
- [Rails](#rails)
   - [Controllers](#controllers)
   - [A common context](#a-common-context)
   - [Flash messages](#flash-messages)
   - [Validation errors](#validation-errors)
- [Fields serialized by default](#fields-serialized-by-default)
   - [Another mode for some serializers](#another-mode-for-some-serializers)
- [Why `many: false`](#why-many-false)
- [Selecting fields](#selecting-fields)

<!-- tocstop -->

## Step by step

### 1. Serialize the records

```ruby
module Serializers
  class Base < Serega
    config.hide_by_default = :auto # relations and batches only on request
  end

  class User < Base
    attribute :id
    attribute :name
  end
end
```

With `hide_by_default = :auto`, attributes that load more data are serialized
only when the client requests them. The default, `false`, serializes every
attribute and hides nothing. See
[Fields serialized by default](#fields-serialized-by-default).

### 2. Describe `meta`

`Serializers::Meta` serializes `meta` of every response. It receives the
record or the whole list, and adds any attributes: constants and values from
the [context](context.md).

```ruby
module Serializers
  # Meta of every response; receives the record or the whole list
  class Meta < Base
    attribute :version, const: "1"
    attribute :request_id, value: proc { |_object, ctx| ctx[:request_id] }, unless_value: :nil?
  end
end
```

### 3. Add a common response shape

`Serializers::Response` gives every response the same shape, `data` and
`meta`, often called a response envelope, so you don't write a `Show` and an
`Index` serializer for each resource. It is not part of Serega: it is a plain
Ruby technique that skips this boilerplate. It is your code, so change it as
your API needs, for example add `links` or `errors`, or make `meta` optional.

```ruby
module Serializers
  # Response serializers of one shape: the records under `data`, and `meta`
  # from a serializer that receives them too
  module Response
    # One record under `data`
    def self.one(data:, meta: Meta)
      Class.new(Base) do
        config.many = false # one {data:, meta:}, not [{data:, meta:}, {data:, meta:}, ...]
        attribute :data, serializer: data, method: :itself # Ruby's Object#itself
        attribute :meta, serializer: meta, method: :itself
      end
    end

    # A list under `data`; the `meta` serializer receives the whole list
    def self.list(data:, meta: Meta)
      Class.new(Base) do
        config.many = false # one {data:, meta:}, not [{data:, meta:}, {data:, meta:}, ...]
        attribute :data, serializer: data, method: :itself, many: true # Ruby's Object#itself
        attribute :meta, serializer: meta, method: :itself, many: false # the list as one object
      end
    end
  end
end
```

### 4. Serialize responses

```ruby
USER_SERIALIZER = Serializers::Response.one(data: Serializers::User)
USERS_SERIALIZER = Serializers::Response.list(data: Serializers::User)

USER_SERIALIZER.to_json(user)
# => {"data":{"id":1,"name":"Bruce Wayne"},"meta":{"version":"1"}}

USERS_SERIALIZER.to_json(users, context: {request_id: "f3a9"})
# => {"data":[{"id":1,"name":"Bruce Wayne"}],"meta":{"version":"1","request_id":"f3a9"}}
```

- Build response serializers once, in constants. Each `one` or `list` call
  builds a new class with its own [plan cache](serializing.md#plan-cache),
  thus a call per request builds the class and its plans again.
- A constant names the class, so errors show `USERS_SERIALIZER`.
- `Response.one` and `Response.list` set `config.many = false`, so a call
  serializes the whole list as one response, `{data:, meta:}`, not an Array of
  responses. See [Why `many: false`](#why-many-false).

## ActiveRecord

### Preloads instead of `includes`

`plugin :activerecord_preloads` with `config.auto_preload = true` preloads the
relations of the serialized fields. Don't add `includes` or `preload` to the
query: the serializer knows which relations the client requested.

```ruby
module Serializers
  class Base < Serega
    plugin :activerecord_preloads
    config.auto_preload = true
    config.hide_by_default = :auto
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
# => {"data":[{"id":1,"name":"Bruce Wayne"}],"meta":{"version":"1"}}

USERS_SERIALIZER.to_json(users, with: "data(posts)") # users are loaded already
# SELECT "posts".* FROM "posts" WHERE "posts"."user_id" IN (1, 2, ...)
# => {"data":[{"id":1,"name":"Bruce Wayne","posts":[{"id":1,"title":"Gotham"}]}],"meta":{"version":"1"}}
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

## Without ActiveRecord

Records from an HTTP API, Sequel, ROM or plain Ruby objects work the same way.
Load the values they don't hold with a [batch loader](batch-loading.md): one
request for all users, not one per user.

```ruby
User = Data.define(:id, :name) # for example, parsed from an HTTP API

module Serializers
  class User < Base
    # One request for all users; returns {user_id => url}
    batch :avatar_url, ->(users) { AvatarService.urls(users.map(&:id)) }

    attribute :id
    attribute :name
    attribute :avatar_url, batch: true
  end
end

USERS_SERIALIZER.to_json(users, with: "data(avatar_url)")
# => {"data":[{"id":1,"name":"Bruce Wayne","avatar_url":"https://..."}],"meta":{"version":"1"}}
```

`avatar_url` has a batch loader, so the service is called only when a client
requests the field.

Without `.page` on the records, paging comes from the
[context](context.md), for example a Pagy object or a Hash built from the API
response:

```ruby
module Serializers
  class Paging < Base
    attribute :page, hash_access: true
    attribute :per_page, hash_access: true
    attribute :total_count, hash_access: true
  end

  class Meta < Base
    attribute :version, const: "1"
    attribute :request_id, value: proc { |_object, ctx| ctx[:request_id] }, unless_value: :nil?
    attribute :paging, serializer: Paging, value: proc { |_object, ctx| ctx[:paging] }, unless_value: :nil?
  end
end

USERS_SERIALIZER.to_json(users, context: {paging: {page: 1, per_page: 20, total_count: 1}})
# => {"data":[...],"meta":{"version":"1","paging":{"page":1,"per_page":20,"total_count":1}}}
```

Records loaded as Hashes read their keys with `hash_access`, see
[Hash Records](hash-records.md).

## Rails

### Controllers

Controllers keep the response serializers in constants and render JSON with
`json`, an `ApplicationController` method that adds the
[common context](#a-common-context):

```ruby
class UsersController < ApplicationController
  USER_SERIALIZER = Serializers::Response.one(data: Serializers::User)
  USERS_SERIALIZER = Serializers::Response.list(data: Serializers::User)

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

### A common context

Most responses need the same [context](context.md): the current user, the
request id. Build it in one method of `ApplicationController`, as a serializer
has no access to the request. `json` serializes with it, and with the fields
the request [selects](#selecting-fields) in its `only`, `with`, `except` and
`preset` parameters:

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
{"data":[{"id":1,"name":"Bruce Wayne"},{"id":2,"name":"Alfred"}],"meta":{"version":"1","request_id":"f3a9"}}
The proc is not called, so the user is not found.

GET /users?with=data(editable)
{"data":[{"id":1,"name":"Bruce Wayne","editable":true},{"id":2,"name":"Alfred","editable":false}],
 "meta":{"version":"1","request_id":"f3a9"}}

GET /users?only=data(nickname)
400 {"errors":[{"source":"fields","title":"Not existing attributes: data(nickname)"}]}
```

A `:value` proc runs once per object, so the proc runs once per user. Rails
apps usually memoize `current_user`, which keeps the lookup to one query; a
[batch loader](batch-loading.md#values-for-the-current-user) calls the proc
once per serialization. Where there is no request, as in a mailer, pass
`current_user: proc {}`, and the same serializers work.

### Flash messages

`notice` and `alert`, the names of Rails flash messages, go to `meta` the
same way as `request_id`: pass them in the context, and add them to `Meta`.

```ruby
attribute :notice, value: proc { |_object, ctx| ctx[:notice] }, unless_value: :nil?
attribute :alert, value: proc { |_object, ctx| ctx[:alert] }, unless_value: :nil?
```

API-only apps have no flash, so the controller adds the messages itself:
`json(USERS_SERIALIZER, users, context: {notice: "Users imported"})`. Other
apps add them to `serialization_context`:
`notice: flash[:notice], alert: flash[:alert]`.

### Validation errors

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
record, so actions don't check for errors. One handler in
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

## Fields serialized by default

`config.hide_by_default` chooses what a response serializes when the client
names no fields. Each mode fits its own case:

- `false`, the default: every attribute. Fits small serializers and internal
  APIs, where a response is the whole record.
- `true`: no attribute, unless it has `hide: false`. Every call names its
  fields with `only:` or `with:`, which fits mailers, exports and APIs whose
  clients always choose fields. The `data` and `meta` attributes of
  `Response` then need `hide: false` to stay in the response.
- `:auto`: every attribute except those with a preload or a batch loader:
  relations preloaded with `auto_preload`, and batch-loaded values. A response
  runs no extra query until a client requests such a field. This fits most
  APIs.

A plain relation without a preload stays visible with `:auto`, and so do
`data`, `meta` and `paging`: `method: :itself` is never preloaded. See
[Hiding by default](selecting-fields.md#hiding-by-default).

### Another mode for some serializers

`Base` is a convention, not a requirement: the mode belongs to each
serializer. A serializer can change it, inherit another base serializer, or
inherit `Serega` directly with its own config. For example, a dashboard that
always shows its relations:

```ruby
module Serializers
  # Relations of the dashboard are serialized by default
  class Dashboard < Base
    config.hide_by_default = false

    attribute :name
    attribute :posts, serializer: Post, many: true
  end

  # Report serializers share their own config, apart from Base
  class ReportBase < Serega
    plugin :activerecord_preloads
    config.auto_preload = true
  end
end
```

A serializer reads the mode when it defines an attribute, so a change affects
the attributes defined after it. Attributes inherited from the parent keep the
parent's mode. Related serializers follow their own config.

## Why `many: false`

Serega serializes a scope or an Array as a list. A response serializer gets
the whole list as one object, thus:

- `config.many = false` in `Response` builds one response from the list, not
  one per user. A `many:` option of a call overrides it;
- `many: false` on `meta` and `paging` passes the list as one object, so
  `Paging` can call `current_page` and the other Kaminari methods;
- `many: true` on `data` serializes each user.

Without `many: false` on `paging`, Serega calls the methods of `Paging` on
each user and raises
`NoMethodError: undefined method 'current_page' for an instance of User`.

## Selecting fields

Clients select fields from the root of the response. `meta` is left out
unless the selection names it:

```ruby
USERS_SERIALIZER.to_json(users, only: "data(id,name),meta")
# => {"data":[{"id":1,"name":"Bruce Wayne"}],"meta":{"version":"1","paging":{...}}}

USERS_SERIALIZER.to_json(users, only: "data(id)")
# => {"data":[{"id":1}]}

USERS_SERIALIZER.to_json(users, only: "data(id),meta(paging(total_count))")
# => {"data":[{"id":1}],"meta":{"paging":{"total_count":1}}}
```

When `?fields=` names the fields of the records, nest them under `data`. An
Array of names works; a String inside a Hash is not parsed:

```ruby
fields = params[:fields]&.split(",") # ?fields=id,name
USERS_SERIALIZER.to_json(users, only: fields && {data: fields, meta: nil})
```

See [Selecting Fields](selecting-fields.md).
