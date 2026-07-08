# Serega Cheatsheet

## 1. Your First Serializer

```ruby
class UserSerializer < Serega
  attribute :name
  attribute :email
end

user = OpenStruct.new(name: 'Felonious Gru', email: 'gru@example.com')
UserSerializer.to_h(user)
# => {name: "Felonious Gru", email: "gru@example.com"}
```

Each `attribute :name` calls `object.name` and adds it to the hash.

---

## 2. Attribute Options

### default — calls method of the same name

```ruby
class UserSerializer < Serega
  attribute :first_name
end

UserSerializer.to_h(OpenStruct.new(first_name: 'Felonious'))
# => {first_name: "Felonious"}
```

### `method:` — call a different method

```ruby
class UserSerializer < Serega
  attribute :name, method: :full_name
end

UserSerializer.to_h(OpenStruct.new(full_name: 'Felonious Gru'))
# => {name: "Felonious Gru"}
```

### block — computed value

```ruby
class UserSerializer < Serega
  attribute(:greeting) { |user| "Hello, #{user.first_name}" }
end

UserSerializer.to_h(OpenStruct.new(first_name: 'Felonious'))
# => {greeting: "Hello, Felonious"}
```

### `value:` — callable

Signatures: `(obj)`, `(obj, ctx:)`, `(obj, batches:)`, `(obj, ctx:, batches:)`,
`(obj, context)` (see [§5 Context][context], [§7 Batch Loading][batch-loading]).

```ruby
class UserSerializer < Serega
  attribute :quote, value: proc { |user, ctx| "#{user.first_name}: #{ctx[:line]}" }
end

UserSerializer.to_h(OpenStruct.new(first_name: 'Felonious'),
                    context: { line: 'Light bulb!' })
# => {quote: "Felonious: Light bulb!"}
```

### `delegate:` — `object.to.method`

```ruby
class UserSerializer < Serega
  attribute :city, delegate: { to: :address, allow_nil: true }
end

UserSerializer.to_h(OpenStruct.new(address: nil))
# => {city: nil}

UserSerializer.to_h(OpenStruct.new(address: OpenStruct.new(city: 'Suburbia')))
# => {city: "Suburbia"}
```

`delegate: { to: :address, method: :town }` calls `object.address.town`.
`delegate: { to: :address, method: :town, allow_nil: true }` calls `object.address&.town`.

### `const:` — fixed value

```ruby
class UserSerializer < Serega
  attribute :role, const: 'admin'
end

UserSerializer.to_h(OpenStruct.new)
# => {role: "admin"}
```

### `default:` — replace nil

```ruby
class UserSerializer < Serega
  attribute :nickname, default: 'anonymous'
end

UserSerializer.to_h(OpenStruct.new(nickname: nil))
# => {nickname: "anonymous"}

UserSerializer.to_h(OpenStruct.new(nickname: 'Vector'))
# => {nickname: "Vector"}
```

### `hide:` — skip unless explicitly requested (see [§4 Field Selection][field-selection])

```ruby
class UserSerializer < Serega
  attribute :email
  attribute :phone, hide: true
end

UserSerializer.to_h(OpenStruct.new(email: 'gru@example.com', phone: '555-1234'))
# => {email: "gru@example.com"}

UserSerializer.to_h(OpenStruct.new(email: 'gru@example.com', phone: '555-1234'), with: :phone)
# => {email: "gru@example.com", phone: "555-1234"}
```

⚠️ Attribute names must match `[a-zA-Z0-9_-~]` (URL-safe). Disable with `config.check_attribute_name = false`.

---

## 3. Serialize

```ruby
class UserSerializer < Serega
  attribute :name
end
user = OpenStruct.new(name: 'Felonious Gru')

UserSerializer.to_h(user) # => {name: "Felonious Gru"}
UserSerializer.to_h([user]) # auto array detection => [{name: "Felonious Gru"}]
UserSerializer.to_data(user) # Ruby Data object (3.2+) => #<data name="Felonious Gru">
UserSerializer.new(only: [:name]).to_h(user) # reuse — serialization plan built once
```

```ruby
# Struct is Enumerable — force single (see [§6 Relations][relations] for `many:`)
quote = Struct.new(:text).new('I am going to steal the moon')
QuoteSerializer.to_h(quote, many: false)
```

---

## 4. Field Selection — `:only` `:except` `:with`

```ruby
class UserSerializer < Serega
  attribute :name
  attribute :email
  attribute :phone, hide: true
end
user = OpenStruct.new(name: 'Felonious', email: 'gru@example.com', phone: '555-1234')

UserSerializer.to_h(user, only: [:name]) # => {name: "Felonious"}
UserSerializer.to_h(user, except: [:email]) # => {name: "Felonious"}
UserSerializer.to_h(user, with: [:phone]) # => {name: "Felonious", email: "gru@example.com", phone: "555-1234"}
```

```ruby
# Nested
UserSerializer.to_h(user, only: [:name, { posts: [:title] }])
```

```ruby
# Unknown attribute
UserSerializer.to_h(user, only: [:address])
# => raises Serega::AttributeNotExist

UserSerializer.to_h(user, only: [:address], check_initiate_params: false)
# => {}
```

---

## 5. Context

```ruby
class UserSerializer < Serega
  attribute(:email) { |user, ctx| user.email if ctx[:current_user] == user }
end
user = OpenStruct.new(email: 'gru@example.com')

UserSerializer.to_h(user, context: { current_user: user }) # => {email: "gru@example.com"}
UserSerializer.to_h(user, context: { current_user: nil }) # => {email: nil}
```

Inside `Presenter` methods context is accessed via `__ctx__` (see [§16 Plugin `:presenter`][plugin-presenter]).

---

## 6. Relations

```ruby
class CommentSerializer < Serega
  attribute :body
end

class PostSerializer < Serega
  attribute :title
  attribute :comments, serializer: CommentSerializer
end

post = OpenStruct.new(title: 'How to Steal the Moon',
                      comments: [OpenStruct.new(body: 'Great post!')])
PostSerializer.to_h(post)
# => {title: "How to Steal the Moon", comments: [{body: "Great post!"}]}
```

```ruby
# Cyclic references / lazy
attribute :comments, serializer: 'CommentSerializer'
attribute :comments, serializer: -> { CommentSerializer }
attribute :comments, serializer: CommentSerializer, many: true # force collection
```

DB preloads for `:serializer` attributes — see [§8 Preloads][preloads].
Force `many:` on every relation — see [§18 Plugin `:explicit_many_option`][plugin-explicit_many_option].

---

## 7. Batch Loading (N+1)

```ruby
class UserSerializer < Serega
  batch :comments_count, ->(users) { users.to_h { |u| [u.id, u.id * 10] } }

  attribute :comments_count, batch: true
end

UserSerializer.to_h([OpenStruct.new(id: 1), OpenStruct.new(id: 2)])
# => [{comments_count: 10}, {comments_count: 20}]
```

Other forms:

```ruby
attribute :comments_count, batch: { use: :comments_count, id: :id } # explicit
attribute :comments_count, batch: { use: ->(users) { ... } } # inline loader

# Multiple loaders — note the keyword is `batches:` (plural)
attribute :total_likes, batch: { use: [:fb_likes, :tw_likes] },
  value: proc { |user, batches:| batches[:fb_likes][user.id] + batches[:tw_likes][user.id] }
```

⚠️ Value-proc keyword is **`batches:`** (plural). `config.batch_id_option = :id` is the default ID method.

Pairs well with `:preload` to avoid N+1 inside loaders (see [§8 Preloads][preloads]).

---

## 8. Preloads

```ruby
class PostSerializer < Serega
  attribute :verified_comments, preload: :comments,
    value: proc { |post| post.comments.select(&:verified?) }
end
```

### `preload:` value semantics

The value is passed to the preload handler exactly as written — `:activerecord_preloads`
hands it straight to `ActiveRecord::Associations::Preloader`.

| Value | Effect |
|---------------|--------------------------|
| `:assoc` | preloads the `:assoc` association onto the serialized objects |
| `[:a, :b]` / `{a: :b}` / custom | passed through as-is to the preload handler |
| `nil` | preloads nothing (also blocks `auto_preload`) |
| `false` | preloads nothing (also blocks `auto_preload`) |
| `true` | invalid — raises when the attribute is defined |

```ruby
class AddressSerializer < Serega
  attribute :country, preload: :country
end
```

```ruby
class UserSerializer < Serega
  attribute :address, serializer: AddressSerializer, preload: :address
end
```

`:address` is preloaded onto the users, and `:country` onto the addresses.

### How preloads actually work

The loading is done by a handler registered with `preload_with`, called once per
preloaded attribute with the gathered objects and that attribute's `:preload`
value:

```ruby
class AppSerializer < Serega
  preload_with { |objects, preloads| MyORM.preload(objects, preloads) }
end
```

[§11 Plugin `:activerecord_preloads`][plugin-activerecord_preloads] registers one
for you (built on `ActiveRecord::Associations::Preloader`), so enabling it loads
every declared association once, automatically — no N+1. For another ORM — or for
plain non-ORM objects — register your own handler: it can load data from any
source and attach it to the objects by your own rules. Declaring `:preload` with
no registered handler raises an error.

The handler runs **once per preloaded attribute** — the same `:preload` value on
several attributes calls it once for each, so a custom handler should check
whether the data is already loaded before loading it again.

Because the `:preload` value is yours to choose (not necessarily an association
name), it doubles as a **discriminator** — give attributes different `:preload`
values and branch on `preloads` in the handler:

```ruby
attribute :owner,  serializer: UserSerializer, preload: :owner
attribute :author, serializer: UserSerializer, preload: :author

preload_with do |objects, preloads|
  case preloads
  when :owner  then load_owners(objects)
  when :author then load_authors(objects)
  else MyORM.preload(objects, preloads)
  end
end
```

`config.auto_preload` saves you from writing `preload:` by hand — when enabled,
attributes with `:serializer` or `:delegate` get a `:preload` inferred from that
option's target.

---

## 9. Sharing Setup via Inheritance

A child serializer inherits attributes, config, and plugins from its parent.
Define a base serializer once, then put shared setup there.

```ruby
class AppSerializer < Serega
  plugin :string_modifiers      # shared by every subclass
  config.check_initiate_params = false
end

class UserSerializer < AppSerializer
  attribute :name
end

class PostSerializer < AppSerializer
  attribute :title
end
```

Both `UserSerializer` and `PostSerializer` now have `:string_modifiers` enabled — no need to opt in twice.

Set defaults in the base class — see [§10 Configuration][configuration], §11–§19 for plugins.

---

## 10. Configuration

### `config.auto_preload` — auto-add `:preload` from `:delegate` / `:serializer`

```ruby
class UserSerializer < Serega
  config.auto_preload = true
  attribute :city, delegate: { to: :address, method: :city }
end
# `:address` is preloaded automatically (from the :delegate option)
```

Default `false`. `true` is sugar for both flags on. Pass a Hash to opt in to
just one:

```ruby
class UserSerializer < Serega
  config.auto_preload = { has_serializer_option: true, has_delegate_option: false }
  attribute :city,  delegate:   { to: :address, method: :city }   # no auto-preload
  attribute :posts, serializer: PostSerializer                     # auto-preloaded
end
```

See [§8 Preloads][preloads].

### `config.hide_by_default` — hide attrs unless explicitly requested

```ruby
class UserSerializer < Serega
  config.hide_by_default = [:preload]
  attribute :name
  attribute :stats, preload: :stats, value: proc { |u| u.stats }
end

UserSerializer.to_h(user)               # => {name: "Felonious"}        (stats skipped)
UserSerializer.to_h(user, with: :stats) # => {name: "Felonious", stats: ...}
```

Accepts `false` (default), `true` (hide everything),
`[:preload]`, `[:batch]`, or `%i[preload batch]`.

`[:preload]` covers **both** kinds of preload: attributes you declared
`preload:` on explicitly, and attributes that got a virtual `preload:` via
`config.auto_preload` (`:delegate` / `:serializer` targets). The typical setup
is `auto_preload = true` + `hide_by_default = [:preload]` — every association
is hidden until the client asks for it, so unrequested fields cost nothing.

See [§4 Field Selection][field-selection].

### `config.delegate_default_allow_nil` — default `:allow_nil` for every `:delegate`

```ruby
class UserSerializer < Serega
  config.delegate_default_allow_nil = true
  attribute :city, delegate: { to: :address }
end
UserSerializer.to_h(OpenStruct.new(address: nil))   # => {city: nil}
```

Default `false` — without this, a nil target raises `NoMethodError`.

### `config.batch_id_option` — default method for batch IDs

```ruby
class UserSerializer < Serega
  config.batch_id_option = :uuid
  batch :likes, ->(users) { users.to_h { |u| [u.uuid, 99] } }
  attribute :likes, batch: true   # uses :uuid instead of :id
end
UserSerializer.to_h([OpenStruct.new(uuid: 'abc')])   # => [{likes: 99}]
```

Default `:id`. See [§7 Batch Loading][batch-loading].

### `config.check_initiate_params` — validate `:only` / `:except` / `:with`

```ruby
class UserSerializer < Serega
  config.check_initiate_params = false
  attribute :name
end
UserSerializer.to_h(user, only: [:nope])   # => {}        (silently skipped)
# default `true` would raise Serega::AttributeNotExist
```

Common pattern: `false` in production, `true` in dev/test.

### `config.check_attribute_name` — URL-safe attribute names

```ruby
class UserSerializer < Serega
  config.check_attribute_name = false
  attribute :"weird.name"   # would otherwise raise
end
```

Default `true` — names must match `[a-zA-Z0-9_-~]`.

### `config.max_cached_plans_per_serializer_count` — plan cache

Caches prepared serialization plans by `:only` / `:except` / `:with` signature
so repeated requests with the same modifiers skip rebuilding. Default `0`
(disabled). No effect on output — purely a performance tuning knob.

---

## 11. Plugin `:activerecord_preloads`

```ruby
class AppSerializer < Serega
  plugin :activerecord_preloads
end

UserSerializer.to_h(user) # AR Preloader runs declared preloads automatically
```

Needs preloads declared on attributes — see [§8 Preloads][preloads].

---

## 12. Plugin `:string_modifiers`

```ruby
class UserSerializer < Serega
  plugin :string_modifiers
  attribute :first_name
  attribute :last_name
end

UserSerializer.to_h(OpenStruct.new(first_name: 'Felonious', last_name: 'Gru'),
                    only: 'first_name')
# => {first_name: "Felonious"}

# Nested:
UserSerializer.to_h(post, only: 'title,author(first_name,email)')
```

Old Hash/Array forms still work. Great for `GET ?fields=...` query params.

---

## 13. Plugin `:camel_case`

```ruby
class UserSerializer < Serega
  plugin :camel_case
  attribute :first_name
  attribute :last_name
  attribute :full_name, camel_case: false # opt out
end

UserSerializer.to_h(OpenStruct.new(first_name: 'Felonious', last_name: 'Gru', full_name: 'Felonious Gru'))
# => {firstName: "Felonious", lastName: "Gru", full_name: "Felonious Gru"}
```

⚠️ Modifiers must use camelCase. Doesn't touch `:root` / `:metadata` keys.
Custom transform: `plugin :camel_case, transform: ->(name) { name.camelize }`.

---

## 14. Plugin `:if` / `:unless`

| Option | Sees | Decides before |
|------------------|------------------|----------------|
| `if:` | `(object, ctx)` | computing value |
| `unless:` | `(object, ctx)` | computing value |
| `if_value:` | `(value, ctx)` | after value built |
| `unless_value:` | `(value, ctx)` | after value built |

```ruby
class UserSerializer < Serega
  plugin :if
  attribute :email, if: proc { |user, ctx| ctx[:current_user] == user }
  attribute :nickname, unless_value: :empty?
end

user = OpenStruct.new(email: 'gru@example.com', nickname: '')

UserSerializer.to_h(user, context: { current_user: nil }) # => {}
UserSerializer.to_h(user, context: { current_user: user }) # => {email: "gru@example.com"}
```

Symbol short form: `if: :active?` → calls `object.active?`.

⚠️ `if_value`/`unless_value` cannot be combined with `:serializer` — use `if`/`unless` there.

For unconditional hiding, prefer `hide: true` — see [§2 Attribute Options][attributes] and [§4 Field Selection][field-selection].

---

## 15. Plugin `:formatters`

```ruby
class AppSerializer < Serega
  plugin :formatters, formatters: {
    iso8601: ->(time) { time.iso8601(3) },
    money: ->(value, ctx) { "$#{value / (10 ** ctx[:digits])}" },
    yes_no: ->(value) { value ? 'yes' : 'no' }
  }
end

class UserSerializer < AppSerializer
  attribute :balance, format: :money
  attribute :active, format: :yes_no
  attribute :score, format: proc { |v| "#{v}%" } # inline
end

UserSerializer.to_h(OpenStruct.new(balance: 100_000, active: true, score: 87),
                    context: { digits: 2 })
# => {balance: "$1000", active: "yes", score: "87%"}
```

---

## 16. Plugin `:presenter`

```ruby
class UserSerializer < Serega
  plugin :presenter

  attribute :full_name
  attribute :role

  class Presenter # < SimpleDelegator (inherits all methods of the wrapped object)
    def full_name
      "#{first_name} #{last_name}"
    end

    def role
      id == __ctx__[:current_user_id] ? :self : :other # context via __ctx__
    end
  end
end

UserSerializer.to_h(OpenStruct.new(first_name: 'Felonious', last_name: 'Gru', id: 1),
                    context: { current_user_id: 1 })
# => {full_name: "Felonious Gru", role: :self}
```

`__getobj__` returns the wrapped object. `method_missing` installs a real
delegator on first call. `__ctx__` exposes the serialization context
(see [§5 Context][context]).

---

## 17. Plugin `:depth_limit`

```ruby
class CommentSerializer < Serega
  plugin :depth_limit, limit: 2
  attribute :replies, serializer: -> { CommentSerializer }
end

CommentSerializer.new(with: { replies: { replies: { replies: :replies } } })
# => raises Serega::DepthLimitError (#details has breach info)
```

Per-serializer override: `config.depth_limit.limit = 5`. Checked at `.new` —
instantiate before business logic to fail fast on malicious `?with=` queries.

---

## 18. Plugin `:explicit_many_option`

```ruby
class AppSerializer < Serega
  plugin :explicit_many_option
end

class PostSerializer < AppSerializer
  attribute :author, serializer: -> { UserSerializer }
end
# => raises Serega::SeregaError: Attribute option :many [Boolean] must be provided

# Fix:
attribute :author, serializer: -> { UserSerializer }, many: false
attribute :comments, serializer: -> { CommentSerializer }, many: true
```

---

## 19. Plugin `:root` / `:metadata` / `:context_metadata`

```ruby
class UserSerializer < Serega
  plugin :root
end

UserSerializer.to_h(nil) # => {data: nil}
UserSerializer.to_h(nil, root: :user) # => {user: nil}
UserSerializer.to_h(nil, root: nil) # => nil
```

```ruby
plugin :root, root: :users # change for all
plugin :root, root_one: :user, root_many: :users # different keys per shape
plugin :root, root: nil # no wrapping by default

# Per-side override:
config.root.one = nil
config.root.many = nil
```

```ruby
class UserSerializer < Serega
  plugin :root
  plugin :metadata
  meta_attribute(:version, const: '1.2.3')
end

UserSerializer.to_h(nil)
# => {data: nil, version: "1.2.3"}
```

```ruby
class UserSerializer < Serega
  plugin :root
  plugin :context_metadata # default key :meta — merges into top level
end

UserSerializer.to_h(nil, meta: { page: 1 })
# => {data: nil, page: 1}
```

Combined (root_one/root_many + metadata + context_metadata):

```ruby
ResponseSerializer.to_h(user, meta: { page: 1 })
# => {user: {first_name: "Felonious"}, show: "Despicable Me", page: 1}

ResponseSerializer.to_h([walter, lucy], meta: { page: 1 })
# => {users: [{first_name: "Felonious"}, {first_name: "Lucy"}], show: "Despicable Me", page: 1}
```

> 💡 **Recommendation:** instead of mixing these three plugins, build an
> envelope serializer with plain `:data` and `:meta` attributes — then every
> response field plays by the same rules (field selection, formatters,
> `if`/`unless`):
>
> ```ruby
> class ResponseSerializer < AppSerializer
> attribute :data, serializer: -> { ... }
> attribute :meta # via :value or block
> end
> ```

---

## 20. Errors

| Error | When |
|--------------------------------|------|
| `Serega::SeregaError` | base class for everything |
| `Serega::AttributeNotExist` | unknown attr in [§4][field-selection] — `#serializer`, `#attributes` |
| `Serega::DepthLimitError` | [§17][plugin-depth_limit] breach — `#details` |

[attributes]: #2-attribute-options
[field-selection]: #4-field-selection--only-except-with
[context]: #5-context
[relations]: #6-relations
[batch-loading]: #7-batch-loading-n1
[preloads]: #8-preloads
[configuration]: #10-configuration
[plugin-activerecord_preloads]: #11-plugin-activerecord_preloads
[plugin-presenter]: #16-plugin-presenter
[plugin-depth_limit]: #17-plugin-depth_limit
[plugin-explicit_many_option]: #18-plugin-explicit_many_option
