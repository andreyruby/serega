# Migrating from the Root and Metadata Plugins

`plugin :root`, `plugin :metadata` and `plugin :context_metadata` are
deprecated. A [response serializer](responses.md) replaces them: a serializer
with `data` and `meta` attributes.

Before, with the deprecated plugins:

```ruby
class AppSerializer < Serega
  plugin :root, root_one: :user, root_many: :users
  plugin :metadata
  plugin :context_metadata

  meta_attribute :version, const: "1.2.3"
end

UserSerializer.to_h(users, meta: {request_id: request.uuid})
# => {users: [...], version: "1.2.3", request_id: "..."}
```

After, with a response serializer:

```ruby
module Serializers
  module Responses
    module Users
      class Index < Base
        attribute :users, serializer: Serializers::User, method: :itself, many: true # Ruby's Object#itself
        attribute :version, const: "1.2.3"
        attribute :request_id, value: proc { |_users, ctx| ctx[:request_id] }
      end
    end
  end
end

Serializers::Responses::Users::Index.to_h(users, many: false, context: {request_id: request.uuid})
# => {users: [...], version: "1.2.3", request_id: "..."}
```

- `plugin :root`: the `data` attribute, or an attribute named like the root key.
- `root_one:` and `root_many:`: `Response.one` and `Response.list` of
  [step 3](responses.md#3-add-a-common-response-shape), or one response serializer each.
- `to_h(user, root: nil)`: serialize with the record serializer itself.
- `meta_attribute :meta, :paging do |records, ctx| ... end`: a meta
  serializer with a `paging` attribute, see [step 2](responses.md#2-describe-meta).
- `hide_nil: true`: `unless_value: :nil?`, see
  [Conditional Attributes](conditional-attributes.md).
- `meta:` of `plugin :context_metadata`: the [context](context.md), read in an
  attribute value.
