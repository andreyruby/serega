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

Response serializers replace the [root and metadata plugins](root-and-metadata.md),
see [Migrating from the Root and Metadata Plugins](migrating-from-root-and-metadata.md).

## Table of Contents

<!-- toc -->

- [Step by step](#step-by-step)
   - [1. Make `app/serializers` the `Serializers` namespace](#1-make-appserializers-the-serializers-namespace)
   - [2. Add a base serializer](#2-add-a-base-serializer)
   - [3. Serialize the records](#3-serialize-the-records)
   - [4. Serialize the paging of a scope](#4-serialize-the-paging-of-a-scope)
   - [5. Describe `meta`](#5-describe-meta)
   - [6. Add a response factory](#6-add-a-response-factory)
   - [7. Render responses in the controller](#7-render-responses-in-the-controller)
   - [8. Check the responses](#8-check-the-responses)
- [`many:`](#many)
- [Selecting fields](#selecting-fields)
- [Meta from the context](#meta-from-the-context)

<!-- tocstop -->

## Step by step

These steps build `GET /users` and `GET /users/:id` in a Rails app that pages
users with Kaminari. The files:

```text
config/initializers/serializers.rb  # Step 1
app/serializers/
├── base.rb                         # Step 2: Serializers::Base
├── user.rb                         # Step 3: Serializers::User
├── paging.rb                       # Step 4: Serializers::Paging
├── meta.rb                         # Step 5: Serializers::Meta
└── responses.rb                    # Step 6: Serializers::Responses
app/controllers/users_controller.rb # Step 7
```

### 1. Make `app/serializers` the `Serializers` namespace

Rails autoloads `app/serializers` as a root directory, thus
`app/serializers/user.rb` would define `::User` and clash with the model:

```ruby
# config/initializers/serializers.rb
module Serializers; end
Rails.autoloaders.main.push_dir(Rails.root.join("app/serializers"), namespace: Serializers)
```

### 2. Add a base serializer

```ruby
# app/serializers/base.rb
module Serializers
  class Base < Serega
    plugin :activerecord_preloads
  end
end
```

### 3. Serialize the records

```ruby
# app/serializers/user.rb
module Serializers
  class User < Base
    attribute :id
    attribute :name
  end
end
```

Preloads of `Serializers::User` run for the users under `data`, as for any
relation. See [Preloads](preloads.md).

### 4. Serialize the paging of a scope

```ruby
# app/serializers/paging.rb
module Serializers
  class Paging < Base # Kaminari
    attribute :page, method: :current_page
    attribute :per_page, method: :limit_value
    attribute :total_count
    attribute :total_pages
  end
end
```

### 5. Describe `meta`

`Serializers::Meta` serializes `meta` of every response. It receives the
record or the whole scope, and adds any attributes: constants, values from the
[context](context.md), and nested serializers such as `Paging`.

```ruby
# app/serializers/meta.rb
module Serializers
  # Meta of every response; receives the record or the whole scope
  class Meta < Base
    attribute :version, const: "1"
    attribute :notice, value: proc { |_object, ctx| ctx[:notice] }, unless_value: :nil?
    attribute :alert, value: proc { |_object, ctx| ctx[:alert] }, unless_value: :nil?

    attribute :paging, serializer: Paging, method: :itself, many: false, # the scope as one object
      if: proc { |object| object.is_a?(Kaminari::PageScopeMethods) }      # only Kaminari scopes
  end
end
```

`paging` is added only for a scope paged with Kaminari: `.page` on a relation
or `Kaminari.paginate_array`. A record, an Array or a scope without `.page`
skip it, see [Conditional Attributes](conditional-attributes.md).

`notice` and `alert` are the names of Rails flash messages. API-only Rails
apps have no flash, so the controller passes them in the context; other apps
can pass `context: {notice: flash[:notice], alert: flash[:alert]}`.

### 6. Add a response factory

The factory gives every response the same shape, `data` and `meta`, so
controllers don't need their own `Show` and `Index` classes. It is not part
of Serega: it is a plain Ruby technique that skips this boilerplate. It is
your code, so change it as your API needs, for example add `links` or
`errors`, or make `meta` optional.

```ruby
# app/serializers/responses.rb
module Serializers
  # Builds response serializers: the records under `data`, and `meta` from a
  # serializer that receives them too
  module Responses
    # One record under `data`, for show, create and update
    def self.show(data:, meta: Meta)
      Class.new(Base) do
        attribute :data, serializer: data, method: :itself # Ruby's Object#itself
        attribute :meta, serializer: meta, method: :itself
      end
    end

    # A scope under `data`; the `meta` serializer receives the whole scope
    def self.index(data:, meta: Meta)
      Class.new(Base) do
        attribute :data, serializer: data, method: :itself, many: true # Ruby's Object#itself
        attribute :meta, serializer: meta, method: :itself, many: false # the scope as one object
      end
    end
  end
end
```

### 7. Render responses in the controller

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  SHOW_SERIALIZER = Serializers::Responses.show(data: Serializers::User)
  INDEX_SERIALIZER = Serializers::Responses.index(data: Serializers::User)

  def index
    users = User.order(:id).page(params[:page]).per(20)
    # One response for the whole scope, not one per user
    render json: INDEX_SERIALIZER.to_json(users, many: false, context: {notice: "Users imported"})
  end

  def show
    render json: SHOW_SERIALIZER.to_json(User.find(params[:id]))
  end
end
```

- Build response serializers once, in constants. Each factory call builds a
  new class with its own [plan cache](configuration.md#plan-cache), thus a call
  per request builds the class and its plans again.
- A constant names the class, so errors show `UsersController::INDEX_SERIALIZER`.
- The scope is one object: serialize it with `many: false`, see
  [`many:`](#many).

### 8. Check the responses

`bin/rails zeitwerk:check` confirms the file names match the constants. Then:

```text
GET /users
{"data":[{"id":1,"name":"Bruce Wayne"}],
 "meta":{"version":"1","notice":"Users imported","paging":{"page":1,"per_page":20,"total_count":1,"total_pages":1}}}

GET /users/1
{"data":{"id":1,"name":"Bruce Wayne"},"meta":{"version":"1"}}
```

## `many:`

Serega serializes a scope or an Array as a list. A response serializer gets
the whole scope as one object, thus:

- `to_json(users, many: false)` builds one response, not one per user;
- `many: false` on `meta` and `paging` passes the scope as one object, so
  `Paging` can call `current_page` and the other Kaminari methods;
- `many: true` on `data` serializes each user.

Without `many: false`, Serega calls the methods of `Paging` on each user and
raises `NoMethodError: undefined method 'current_page' for an instance of User`.

## Selecting fields

Clients select fields from the root of the response. `meta` is left out
unless the selection names it:

```ruby
INDEX_SERIALIZER.to_json(users, many: false, only: "data(id,name),meta")
# => {data: [{id: 1, name: "Bruce Wayne"}], meta: {version: "1", paging: {...}}}

INDEX_SERIALIZER.to_json(users, many: false, only: "data(id)")
# => {data: [{id: 1}]}

INDEX_SERIALIZER.to_json(users, many: false, only: "data(id),meta(paging(total_count))")
# => {data: [{id: 1}], meta: {paging: {total_count: 1}}}
```

When `?fields=` names the fields of the records, nest them under `data`. An
Array of names works; a String inside a Hash is not parsed:

```ruby
fields = params[:fields]&.split(",") # ?fields=id,name
INDEX_SERIALIZER.to_json(users, many: false, only: fields && {data: fields, meta: nil})
```

See [Selecting Fields](selecting-fields.md).

## Meta from the context

Values that the records don't know come from the [context](context.md). Pagy,
for example, returns its paging object next to the records. A subclass of
`Meta` redefines `paging` and keeps the other attributes:

```ruby
module Serializers
  class PagyPaging < Base
    attribute :page
    attribute :limit
    attribute :count
    attribute :pages
  end

  class PagyMeta < Meta
    attribute :paging, serializer: PagyPaging, value: proc { |_users, ctx| ctx[:pagy] }
  end
end
```

The controller of [step 7](#7-render-responses-in-the-controller) passes
`PagyMeta` and the paging object:

```diff
-  INDEX_SERIALIZER = Serializers::Responses.index(data: Serializers::User)
+  INDEX_SERIALIZER = Serializers::Responses.index(data: Serializers::User, meta: Serializers::PagyMeta)

   def index
-    users = User.order(:id).page(params[:page]).per(20)
-    render json: INDEX_SERIALIZER.to_json(users, many: false, context: {notice: "Users imported"})
+    pagy, users = pagy(User.order(:id))
+    render json: INDEX_SERIALIZER.to_json(users, many: false, context: {pagy: pagy})
   end
```

The same way, the context carries other request data for `meta`, such as the
applied filters or a request id.
