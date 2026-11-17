# Response Serializers

In this guide, a response serializer wraps the records of an API response
with `data` and adds `meta`, such as paging. It is a plain serializer with a
`data` and a `meta` attribute, so it uses the attribute options you already
know, and clients select its fields from the root, for example
`?only=data(id,name)` (see [Selecting fields](#selecting-fields)).

```json
{
  "data": [{"id": 1, "name": "Felonious Gru"}],
  "meta": {"version": "1", "paging": {"page": 1, "per_page": 20, "total_count": 1, "total_pages": 1}}
}
```

This guide is an example: one of many ways to structure API responses. Take
the parts that fit your API and change the rest.

The examples work in any Ruby app with any records: plain objects, Hashes,
or records from an HTTP API. [Responses in Rails](responses-rails.md) adds
ActiveRecord preloads instead of `includes`, Kaminari paging, controllers and
validation errors.

Response serializers replace the [root and metadata plugins](root-and-metadata.md),
see [Migrating from the Root and Metadata Plugins](migrating-from-root-and-metadata.md).

## Table of Contents

<!-- toc -->

- [Step by step](#step-by-step)
   - [1. Serialize the records](#1-serialize-the-records)
   - [2. Describe `meta`](#2-describe-meta)
   - [3. Add a common response shape](#3-add-a-common-response-shape)
   - [4. Serialize responses](#4-serialize-responses)
- [Loading values in batches](#loading-values-in-batches)
- [Paging](#paging)
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
    configure do |config|
      config.hide_by_default = :auto # relations and batches only on request
    end
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

Here `Serializers::Meta` serializes `meta` of every response. It receives
the record or the whole list, and can add any attributes: constants and
values from the [context](context.md).

`Meta` is your class, so it holds only the fields your API sends. `version`
and `request_id` below are examples: drop them to keep an existing `meta`
unchanged, and add [paging](#paging) when lists need it.

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
    def self.one(serializer, meta: Meta)
      Class.new(Base) do
        config.many = false # one {data:, meta:}, not [{data:, meta:}, {data:, meta:}, ...]
        attribute :data, serializer: serializer, method: :itself # Ruby's Object#itself
        attribute :meta, serializer: meta, method: :itself
      end
    end

    # A list under `data`; the `meta` serializer receives the whole list
    def self.list(serializer, meta: Meta)
      Class.new(Base) do
        config.many = false # one {data:, meta:}, not [{data:, meta:}, {data:, meta:}, ...]
        attribute :data, serializer: serializer, method: :itself, many: true # Ruby's Object#itself
        attribute :meta, serializer: meta, method: :itself, many: false # the list as one object
      end
    end
  end
end
```

### 4. Serialize responses

```ruby
USER_SERIALIZER = Serializers::Response.one(Serializers::User)
USERS_SERIALIZER = Serializers::Response.list(Serializers::User)

USER_SERIALIZER.to_json(user)
# => {"data":{"id":1,"name":"Felonious Gru"},"meta":{"version":"1"}}

USERS_SERIALIZER.to_json(users, context: {request_id: "f3a9"})
# => {"data":[{"id":1,"name":"Felonious Gru"}],"meta":{"version":"1","request_id":"f3a9"}}
```

- Build response serializers once, in constants. Each `one` or `list` call
  builds a new class with its own [plan cache](serializing.md#plan-cache),
  thus a call per request builds the class and its plans again.
- A constant names the class, so errors show `USERS_SERIALIZER`.
- `Response.one` and `Response.list` set `config.many = false`, so a call
  serializes the whole list as one response, `{data:, meta:}`, not an Array of
  responses. See [Why `many: false`](#why-many-false).

## Loading values in batches

Values the records don't hold load with a [batch loader](batch-loading.md):
one request for all users, not one per user. Here the users come from an HTTP
API.

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
# => {"data":[{"id":1,"name":"Felonious Gru","avatar_url":"https://..."}],"meta":{"version":"1"}}
```

`avatar_url` has a batch loader, so the service is called only when a client
requests the field.

With ActiveRecord, relations load with preloads, not `includes`: see
[Preloads instead of `includes`](responses-rails.md#preloads-instead-of-includes).

## Paging

Here paging comes from the [context](context.md), for example a Hash built
from the API response or a Pagy object. With Kaminari, see
[Paging with Kaminari](responses-rails.md#paging-with-kaminari).

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
  runs no extra query until a client requests such a field. Fits APIs whose
  responses have relations or costly fields.

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

  # Export serializers share their own config, apart from Base
  class ExportBase < Serega
    configure do |config|
      config.hide_by_default = true # every export names its fields
    end
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
- `many: false` on `meta` passes the list as one object, so `Meta` reads the
  whole list, for example its paging;
- `many: true` on `data` serializes each user.

## Selecting fields

Clients can request any field of the response: `data`, `meta`, or any
fields inside them. The API passes their selection to the response
serializer unchanged, as the [`json` helper](responses-rails.md#a-common-context) does.

```text
GET /users?only=data(id,name)
GET /users?only=meta(paging(total_count))
GET /users?only=data(id),meta
GET /users?with=data(posts(comments_count))
```

`meta` is left out unless the selection names it:

```ruby
USERS_SERIALIZER.to_json(users, only: "data(id,name),meta")
# => {"data":[{"id":1,"name":"Felonious Gru"}],"meta":{"version":"1","paging":{...}}}

USERS_SERIALIZER.to_json(users, only: "data(id)")
# => {"data":[{"id":1}]}

USERS_SERIALIZER.to_json(users, only: "data(id),meta(paging(total_count))")
# => {"data":[{"id":1}],"meta":{"paging":{"total_count":1}}}
```

To keep an existing `?fields=id,name` parameter that names the fields of the
records, nest its names under `data`:

```ruby
fields = params[:fields]&.split(",") # ?fields=id,name
USERS_SERIALIZER.to_json(users, only: fields && {data: fields, meta: nil})
```

See [Selecting Fields](selecting-fields.md).
