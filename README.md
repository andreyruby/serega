# Serega Ruby Serializer

[![Gem Version](https://badge.fury.io/rb/serega.svg)](https://badge.fury.io/rb/serega)
[![GitHub Actions][build-badge]][build]

The Serega Ruby Serializer provides easy and powerful DSL to describe your
objects and serialize them to Hash or JSON.

---

  📌 Serega does not depend on any gem and works with any framework

---

It has some great features:

- Manually [select serialized fields](#selecting-fields)
- Secure from malicious queries with [depth_limit][depth_limit] plugin
- Solutions for N+1 problem (via built-in [batch loading](#batch-loading), [preloads][preloads] or
  [activerecord_preloads][activerecord_preloads] plugin)
- Built-in object presenter ([presenter][presenter] plugin)
- Adding custom metadata (via [metadata][metadata] or
  [context_metadata][context_metadata] plugins)
- Value formatters ([formatters][formatters] plugin) helps to transform
  time, date, money, percentage, and any other values in the same way
  keeping the code dry
- Conditional attributes - ([if][if] plugin)
- Auto camelCase keys - [camel_case][camel_case] plugin

## Installation

`bundle add serega`

### Define serializers

Most apps should define **base serializer** with common plugins and settings to
not repeat them in each serializer.

Serializers will inherit everything (plugins, config, attributes) from their
superclasses.

```ruby
class AppSerializer < Serega
  # plugin :one
  # plugin :two

  # config.one = :one
  # config.two = :two
end

class UserSerializer < AppSerializer
  # attribute :one
  # attribute :two
end

class CommentSerializer < AppSerializer
  # attribute :one
  # attribute :two
end
```

### Adding attributes

⚠️ Attribute names are checked to include only "a-z", "A-Z", "0-9", "\_", "-",
"~" characters.

We allow ONLY these characters as we want to be able to use attribute names in
URLs without escaping.

This rule can be turned off with simple config option: `config.check_attribute_name = false`

```ruby
class UserSerializer < Serega
  # Regular attribute
  attribute :first_name

  # Option :method specifies the method that must be called on the
  # serialized object
  attribute :first_name, method: :old_first_name

  # Attribute blocks below require a base serializer for nested serializers.
  # See the "Defining a nested serializer with a block" section below.
  config.base_serializer = Serega

  # Method :itself is handy to serialize the same object with a nested set of
  # attributes. Note: with the :presenter plugin the serialized value will be
  # the Presenter instance itself; use `method: :__getobj__` to serialize the
  # original unwrapped object instead.
  attribute :statistics, method: :itself do
    attribute :likes_count
    attribute :comments_count
  end

  # Block defines a nested serializer for the attribute value.
  # See the "Defining a nested serializer with a block" section below.
  attribute :author do
    attribute :name
  end

  # Option :value can be used with a Proc or callable object to define
  # attribute value
  attribute :first_name, value: UserProfile.new # must have #call method
  attribute :first_name, value: proc { |user| user.profile&.first_name }

  # Option :delegate can be used to define attribute value.
  # Sub-option :allow_nil by default is false
  attribute :first_name, delegate: { to: :profile, allow_nil: true }

  # Option :delegate can be used with :method sub-option, so method chain here
  # is user.profile.fname
  attribute :first_name, delegate: { to: :profile, method: :fname }

  # Option :default can be used to replace possible nil values.
  attribute :first_name, default: ''
  attribute :is_active, default: false
  attribute :comments_count, default: 0

  # Option :const specifies attribute with a specific constant value
  attribute(:type, const: 'user')

  # Option :hide specifies attributes that should not be serialized by default
  attribute :tags, hide: true

  # Option :serializer specifies nested serializer for attribute
  # We can define the `:serializer` value as a Class, String, or Proc.
  # Use String or Proc if you have cross-references in serializers.
  attribute :posts, serializer: PostSerializer
  attribute :posts, serializer: "PostSerializer"
  attribute :posts, serializer: -> { PostSerializer }

  # Option `:many` specifies a has_many relationship. It is optional.
  # If not specified, it is defined during serialization by checking
  # `object.is_a?(Enumerable) && !object.is_a?(Struct)`
  # Also the `:many` changes the default value from `nil` to `[]`.
  attribute :posts, serializer: PostSerializer, many: true

  # Option `:preload` allows to specify associations to preload to
  # attribute value
  attribute :email, preload: :emails, value: proc { |user| user.emails.find(&:verified?) }

  # Options `:if, :unless, :if_value and :unless_value` can be specified
  # when `:if` plugin is enabled. They hide the attribute key and value from the
  # response.
  # See more usage examples in the `:if` plugin section.
  attribute :email, if: proc { |user, ctx| user == ctx[:current_user] }
  attribute :email, if_value: :present?

  # Option `:format` can be specified when enabled `:formatters` plugin
  # It changes the attribute value
  attribute :created_at, format: :iso_time
  attribute :updated_at, format: :iso_time

  # Option `:format` also can be used as Proc
  attribute :created_at, format: proc { |time| time.strftime("%Y-%m-%d")}
end
```

### Defining a nested serializer with a block

An attribute block defines an anonymous nested serializer. The attribute value
is found as usual — by the attribute name or the `:method`, `:value`,
`:delegate`, `:batch` option — and is serialized by this nested serializer.

The nested serializer is a regular subclass of an explicitly chosen **base
serializer** — usually a settings-only serializer holding your plugins and
configuration. Choose it with the `base_serializer:` attribute option or the
`config.base_serializer` setting (attribute option wins; an error is raised
when none is set):

```ruby
class AppSerializer < Serega
  plugin :activerecord_preloads

  # Nested serializers defined with attribute blocks will inherit from
  # AppSerializer
  config.base_serializer = self
end

class UserSerializer < AppSerializer
  attribute :first_name

  # Serializes user.author with a nested serializer inherited from AppSerializer
  attribute :author do
    attribute :name
  end

  # Serializes the user itself, exposing only counters
  attribute :statistics, method: :itself, base_serializer: StatsBaseSerializer do
    attribute :likes_count
    attribute :comments_count
  end
end

UserSerializer.to_h(user)
# => {first_name: "Bruce", author: {name: "Bob"}, statistics: {likes_count: 10, comments_count: 3}}
```

⚠️ Blocks can no longer be used to define attribute values — use the
`value: <callable>` option instead. A block that accepts parameters or defines
no attributes raises an error explaining this.

The nested serializer inherits everything the base serializer has — plugins,
config, attributes, batch loaders, the preload handler — through the regular
inheritance mechanism. Any serializer can be used as a base: if it has
attributes, they are serialized by the nested serializer too, together with
the attributes defined in the block. Anything the base does not provide can
be declared inside the block:

```ruby
attribute :statistics, method: :itself do
  batch(:stats) { |users| Stats.for_users(users) } # => { user_id => stat }

  attribute :likes_count, batch: :stats, value: proc { |user, batches:| batches[:stats][user.id].likes }
end
```

Things to keep in mind:

- The nested serializer is created at the moment the attribute is defined.
  Changes made to the base serializer later do not affect already defined
  nested serializers.
- Errors raised while serializing nested attributes are reported with a
  readable serializer label, for example:
  `(when serializing 'comments_count' attribute in UserSerializer.<statistics>)`.

### Serializing

We can serialize objects using class method `.call` aliased as `.to_h` and
same instance methods `#call` and its alias `#to_h`.

```ruby
user = OpenStruct.new(username: 'serega')

class UserSerializer < Serega
  attribute :username
end

UserSerializer.to_h(user) # => {username: "serega"}
UserSerializer.to_h([user]) # => [{username: "serega"}]
```

Use `.to_data` / `#to_data` to get the same result as Ruby `Data` objects
(immutable value objects, Ruby 3.2+). Nested serialized relations are also
converted to `Data` objects.

```ruby
result = UserSerializer.to_data(user)
result         # => #<data username="serega">
result.username # => "serega"

UserSerializer.to_data([user]) # => [#<data username="serega">]
```

If serialized fields are constant, then it's a good idea to initiate the
serializer and reuse it.
It will be a bit faster (the serialization plan will be prepared only once).

```ruby
# Example with all fields
serializer = UserSerializer.new
serializer.to_h(user1)
serializer.to_h(user2)

# Example with custom fields
serializer = UserSerializer.new(only: [:username, :avatar])
serializer.to_h(user1)
serializer.to_h(user2)
```

### Selecting Fields

By default, all attributes are serialized (except marked as `hide: true`).

We can provide **modifiers** to select serialized attributes:

- *only* - lists specific attributes to serialize;
- *except* - lists attributes to not serialize;
- *with* - lists attributes to serialize additionally (By default all attributes
  are exposed and will be serialized, but some attributes can be hidden when
  they are defined with the `hide: true` option, more on this below. `with`
  modifier can be used to expose such attributes).

Modifiers can be provided as Hash, Array, String, Symbol, or their combinations.

With plugin [string_modifiers][string_modifiers] we can provide modifiers as
single `String` with attributes split by comma `,` and nested values inside
brackets `()`, like: `first_name,last_name,addresses(line1,line2)`. This can be very useful
to accept the list of fields in **GET** requests.

When a non-existing attribute is provided, the `Serega::AttributeNotExist` error
will be raised. This error can be muted with the `check_initiate_params: false`
option.

```ruby
class UserSerializer < Serega
  plugin :string_modifiers # to send all modifiers in one string

  attribute :username
  attribute :first_name
  attribute :last_name
  attribute :email, hide: true
  attribute :enemies, serializer: UserSerializer, hide: true
end

joker = OpenStruct.new(
  username: 'The Joker',
  first_name: 'jack',
  last_name: 'Oswald White',
  email: 'joker@mail.com',
  enemies: []
)

bruce = OpenStruct.new(
  username: 'Batman',
  first_name: 'Bruce',
  last_name: 'Wayne',
  email: 'bruce@wayneenterprises.com',
  enemies: []
)

joker.enemies << bruce
bruce.enemies << joker

# Default
UserSerializer.to_h(bruce)
# => {:username=>"Batman", :first_name=>"Bruce", :last_name=>"Wayne"}

# With `:only` modifier
fields = [:username, { enemies: [:username, :email] }]
fields_as_string = 'username,enemies(username,email)'

UserSerializer.to_h(bruce, only: fields)
UserSerializer.new(only: fields).to_h(bruce)
UserSerializer.new(only: fields_as_string).to_h(bruce)
# =>
# {
#   :username=>"Batman",
#   :enemies=>[{:username=>"The Joker", :email=>"joker@mail.com"}]
# }

# With `:except` modifier
fields = %i[first_name last_name]
fields_as_string = 'first_name,last_name'
UserSerializer.new(except: fields).to_h(bruce)
UserSerializer.to_h(bruce, except: fields)
UserSerializer.to_h(bruce, except: fields_as_string)
# => {:username=>"Batman"}

# With `:with` modifier
fields = %i[email enemies]
fields_as_string = 'email,enemies'
UserSerializer.new(with: fields).to_h(bruce)
UserSerializer.to_h(bruce, with: fields)
UserSerializer.to_h(bruce, with: fields_as_string)
# =>
# {
#   :username=>"Batman",
#   :first_name=>"Bruce",
#   :last_name=>"Wayne",
#   :email=>"bruce@wayneenterprises.com",
#   :enemies=>[
#     {:username=>"The Joker", :first_name=>"jack", :last_name=>"Oswald White"}
#   ]
# }

# With no existing attribute
fields = %i[first_name enemy]
fields_as_string = 'first_name,enemy'
UserSerializer.new(only: fields).to_h(bruce)
UserSerializer.to_h(bruce, only: fields)
UserSerializer.to_h(bruce, only: fields_as_string)
# => raises Serega::AttributeNotExist

# With no existing attribute and disabled validation
fields = %i[first_name enemy]
fields_as_string = 'first_name,enemy'
UserSerializer.new(only: fields, check_initiate_params: false).to_h(bruce)
UserSerializer.to_h(bruce, only: fields, check_initiate_params: false)
UserSerializer.to_h(bruce, only: fields_as_string, check_initiate_params: false)
# => {:first_name=>"Bruce"}
```

### Using Context

Sometimes it can be required to use the context during serialization, like
current_user or any.

```ruby
class UserSerializer < Serega
  attribute :email, value: proc { |user, ctx|
    user.email if ctx[:current_user] == user
  }
end

user = OpenStruct.new(email: 'email@example.com')
UserSerializer.(user, context: {current_user: user})
# => {:email=>"email@example.com"}

UserSerializer.new.to_h(user, context: {current_user: user}) # same
# => {:email=>"email@example.com"}
```

### Batch Loading

Serega includes built-in batch loading functionality to efficiently load data on demand and solve N+1 problems.

#### Defining Named Batch Loaders

Named loaders can be defined using the `batch` class method and reused across attributes:

```ruby
class UserSerializer < Serega
  # Define named loaders
  batch :comments_count, ->(users) { Comment.where(user: users).group(:user_id).count }
  batch :comments_count, CommentsCountLoader # Example with callable class

  # Full attribute example
  attribute :comments_count, batch: { use: :comments_count },
    value: proc { |user, batch:| batch[:comments_count][user.id] }

  # Shorter version
  attribute :comments_count, batch: { use: :comments_count, id: :id } # Equivalent, id: :id is default

  # Shortest version
  attribute :comments_count, batch: true # Equivalent
end
```

#### Using Custom Loaders

Custom loaders can be provided directly using the `:use` option with any callable object:

```ruby
class UserSerializer < Serega
  # Inline proc loader
  attribute :followers_count,
    batch: { use: ->(users) { Follow.where(user: users).group(:user_id).count } }

  # Callable class loader
  attribute :likes_count, batch: { use: LikesCountLoader }

  # Method reference
  attribute :views_count, batch: { use: ViewsCounter.method(:batch_load) }
end
```

#### Using Multiple Loaders in Same Attribute

Custom loaders can be provided directly using the `:use` option with any callable object:

```ruby
class UserSerializer < Serega
  # Define named loaders
  batch :facebook_likes, FacebookLikesLoader
  batch :twitter_likes, TwitterLikesLoader

  # Summarize likes
  attribute :likes_count,
    batch: { use: [:facebook_likes, :twitter_likes] },
    value: proc { |user, batch:| batch[:facebook_likes][user.id] + batch[:twitter_likes][user.id] }
end
```

## Configuration

Here are the default options. Other options can be added with plugins.

⚠️ Attributes are prepared at the moment they are defined. If a config option
influences attributes (`auto_preload`, `hide_by_default`, `batch_id_option`,
formatters, etc.), changing it affects only attributes defined **after** the
change — including nested serializers defined with attribute blocks, which
are created at their definition point. Configure the serializer before
defining attributes.

```ruby
class AppSerializer < Serega
  # With `activerecord_preloads` plugin it automatically adds `preload` option
  # to attributes with `:delegate` or `:serializer` option.
  # It helps to preload associations automatically, omitting N+1 requests.
  config.auto_preload = false

  # Methods that are never auto-preloaded — they return the serialized object
  # itself, not an association. Applies to the `:method` option of attributes
  # with a serializer (or a block) and to the `delegate: {to: ...}` option.
  config.safe_auto_preload_methods = [:itself, :__getobj__] # default

  # Hides attributes by default. Accepts:
  #   false         - nothing hidden (default)
  #   true          - all attributes hidden
  #   [:preload]    - attributes with :preload option hidden
  #   [:batch]      - attributes with :batch option hidden
  #   [:preload, :batch] - either option triggers hiding
  # Useful to avoid extra DB requests for attributes that were not requested.
  config.hide_by_default = false

  # Default method used on serialized object to resolve batch value
  # For example:
  #   attribute :counter, batch: CounterBatchLoader
  #   # Attribute values will be resolved as:
  #   proc { |object, batches:| batches[:counter][object.id] }
  config.batch_id_option = :id

  # Parent class for nested serializers defined with attribute blocks.
  # Usually a settings-only serializer, e.g. `config.base_serializer = self`
  # in an application base serializer class. There is no default — an
  # attribute block raises an error when no base serializer is chosen (it can
  # also be provided per-attribute with the `base_serializer:` option).
  config.base_serializer = self

  # Disable/enable validation of modifiers (`:with, :except, :only`)
  # By default, this validation is enabled.
  # After disabling, all requested incorrect attributes will be skipped.
  config.check_initiate_params = false # default is true, enabled

  # Stores in memory prepared `plans` - list of serialized attributes.
  # Next time serialization happens with the same modifiers (`only, except, with`),
  # we will reuse already prepared `plans`.
  # This defines storage size (count of stored `plans` with different modifiers).
  config.max_cached_plans_per_serializer_count = 50 # default is 0, disabled
end
```

## Preloads

Serega includes built-in preloads functionality that lets you declare
`:preload` on attributes. It is used by the `:activerecord_preloads` plugin:
enable it and every association you declare is loaded once during
serialization, automatically, with no N+1.

Configuration options:

- `config.auto_preload` - default `false` (use `true` or `{ has_delegate_option: true, has_serializer_option: true }`)
- `config.hide_by_default` - default `false` (use `:auto` to hide attributes with preloads or batch loaders)

These options are extremely useful if you want to forget about finding
preloads manually.

The `:preload` value is passed to the preload handler exactly as written — a
Symbol, Array, Hash, or any custom value your ORM understands. Preloads can be
disabled with `preload: false` (or `preload: nil`); `preload: true` is not a
valid value. Automatically added preloads can be overwritten with the manually
specified `preload: :xxx` option.

The actual loading is performed by a handler registered with `preload_with`. The
`:activerecord_preloads` plugin registers one for you; to preload with another
ORM — or to attach data to plain non-ORM objects by your own rules — register
your own (see [Custom preloading](#custom-preloading)). Declaring `:preload`
without a registered handler raises an error, so a preload never silently does
nothing.

For some examples, **please read the comments in the code below**

```ruby
class AppSerializer < Serega
  config.auto_preload = true
  config.hide_by_default = :auto
end

class UserSerializer < AppSerializer
  # No preloads
  attribute :username

  # `preload: :user_stats` added manually
  attribute :followers_count, preload: :user_stats,
    value: proc { |user| user.user_stats.followers_count }

  # `preload: :user_stats` added automatically, as
  # `auto_preload` includes `has_delegate_option: true`
  attribute :comments_count, delegate: { to: :user_stats }

  # `preload: :albums` added automatically as
  # `auto_preload` includes `has_serializer_option: true`
  attribute :albums, serializer: 'AlbumSerializer'
end

class AlbumSerializer < AppSerializer
  attribute :images_count, delegate: { to: :album_stats }
end

# With `hide_by_default = :auto`, attributes that declare a preload are hidden
# unless explicitly requested with `:with`. When requested, their associations
# are preloaded automatically. For example:
#
#   UserSerializer.to_h(users, with: [:followers_count, { albums: :images_count }])
#
# preloads `:user_stats` and `:albums` on the users, and `:album_stats` on the
# albums.
```

---

### SPECIFIC CASE: Serializing the same object in association

For example, you show your current user as "user" and use the same user object
to serialize "user_stats". `UserStatSerializer` relies on user fields and any
other user associations. Specify `preload: nil` so that nothing is preloaded for
this attribute on the "user" object — the associations declared in
`UserStatSerializer` are still preloaded onto the same user object.

```ruby
class AppSerializer < Serega
  config.auto_preload = true
  config.hide_by_default = :auto
end

class UserSerializer < AppSerializer
  attribute :username
  attribute :user_stats,
    serializer: 'UserStatSerializer',
    value: proc { |user| user },
    preload: nil
end
```

---

### Custom preloading

The `:activerecord_preloads` plugin works out of the box, but the preload
mechanism itself is not tied to ActiveRecord — or to ORMs at all. Register a
handler with `preload_with` and it is called once per preloaded attribute with
the gathered objects and that attribute's `:preload` value, before the
attribute is serialized:

```ruby
class UserSerializer < Serega
  attribute :name
  attribute :posts, serializer: PostSerializer, preload: :posts

  # `objects` is the gathered users; `preloads` is this attribute's
  # `:preload` value (`:posts`). `MyORM.preload` does the eager loading.
  preload_with { |objects, preloads| MyORM.preload(objects, preloads) }
end
```

The handler can be a block or any callable taking `(objects, preloads)`. It is
inherited by child serializers and can be overridden per subclass. The
`:preload` value reaches the handler untouched, so you can pass whatever your
handler expects — not necessarily something an ORM understands. The gathered
objects can be plain Ruby objects too: the handler decides where the data comes
from (another ORM, an HTTP API, a cache) and how to attach it to the objects,
by whatever rules you define.

The handler runs **once per preloaded attribute**, not once per distinct
`:preload` value. If the same `:preload` is declared on several attributes, the
handler is invoked once for each of them over the same objects, so it should
check whether the data is already loaded before loading it again. (The
`:activerecord_preloads` handler relies on `ActiveRecord::Associations::Preloader`,
which already skips associations that are loaded.)

Because you choose the `:preload` value, it doubles as a **discriminator**: give
two attributes different `:preload` values and branch on `preloads` inside the
handler — no need for the value to be a real association name.

```ruby
class PostSerializer < Serega
  attribute :owner,  serializer: UserSerializer, preload: :owner
  attribute :author, serializer: UserSerializer, preload: :author

  # Both attributes load the same person, but from different sources.
  preload_with do |objects, preloads|
    case preloads
    when :owner  then load_owners(objects)   # e.g. from the DB
    when :author then load_authors(objects)  # e.g. from an external API
    else MyORM.preload(objects, preloads)
    end
  end
end
```

---

## Plugins

### Plugin :activerecord_preloads

Automatically preloads associations to serialized objects.

Every association you declare with `:preload` is loaded once during
serialization using `ActiveRecord::Associations::Preloader`, so there are no
N+1 queries. The plugin does this by registering a [`preload_with`](#custom-preloading)
handler; to use a different ORM, register your own instead.

```ruby
class AppSerializer < Serega
  config.auto_preload = true
  config.hide_by_default = false

  plugin :activerecord_preloads
end

class UserSerializer < AppSerializer
  attribute :username
  attribute :comments_count, delegate: { to: :user_stats }
  attribute :albums, serializer: AlbumSerializer
end

class AlbumSerializer < AppSerializer
  attribute :title
  attribute :downloads_count, preload: :downloads,
    value: proc { |album| album.downloads.count }
end

UserSerializer.to_h(user)
# preloads :user_stats and :albums on the user; the AlbumSerializer level
# preloads :downloads on the albums
```

### Plugin :root

Allows to add root key to your serialized data

Accepts options:

- :root - specifies root for all responses
- :root_one - specifies the root key for single object serialization only
- :root_many - specifies the root key for multiple objects serialization only

Adds additional config options:

- config.root.one
- config.root.many
- config.root.one=
- config.root_many=

The default root is `:data`.

The root key can be changed per serialization.

```ruby
 # @example Change root per serialization:

 class UserSerializer < Serega
   plugin :root
 end

 UserSerializer.to_h(nil)              # => {:data=>nil}
 UserSerializer.to_h(nil, root: :user) # => {:user=>nil}
 UserSerializer.to_h(nil, root: nil)   # => nil
```

The root key can be removed for all responses by providing the `root: nil`
plugin option.

In this case, no root key will be added. But it still can be added manually.

```ruby
 #@example Define :root plugin with different options

 class UserSerializer < Serega
   plugin :root # default root is :data
 end

 class UserSerializer < Serega
   plugin :root, root: :users
 end

 class UserSerializer < Serega
   plugin :root, root_one: :user, root_many: :people
 end

 class UserSerializer < Serega
   plugin :root, root: nil # no root key by default
 end
```

### Plugin :metadata

Depends on: [`:root`][root] plugin, that must be loaded first

Adds ability to describe metadata and adds it to serialized response

Adds class-level `.meta_attribute` method. It accepts:

- `*path` [Array of Symbols] - nested hash keys.
- `**options` [Hash]

   - `:const` - describes metadata value (if it is constant)
   - `:value` - describes metadata value as any `#callable` instance
   - `:hide_nil` - does not show the metadata key if the value is nil.
     It is `false` by default
   - `:hide_empty` - does not show the metadata key if the value is nil or empty.
     It is `false` by default.

- `&block` [Proc] - describes value for the current meta attribute

```ruby
class AppSerializer < Serega
  plugin :root
  plugin :metadata

  meta_attribute(:version, const: '1.2.3')
  meta_attribute(:ab_tests, :names, value: ABTests.new.method(:names))
  meta_attribute(:meta, :paging, hide_nil: true) do |records, ctx|
    next unless records.respond_to?(:total_count)

    {
      page: records.page,
      per_page: records.per_page,
      total_count: records.total_count
    }
  end
end

AppSerializer.to_h(nil)
# => {:data=>nil, :version=>"1.2.3", :ab_tests=>{:names=> ... }}
```

### Plugin :context_metadata

Depends on: [`:root`][root] plugin, that must be loaded first

Allows to provide metadata and attach it to serialized response.

Accepts option `:context_metadata_key` with the name of the root metadata keyword.
By default, it has the `:meta` value.

The key can be changed in children serializers using this method:
`config.context_metadata.key=(value)`.

```ruby
class UserSerializer < Serega
  plugin :root, root: :data
  plugin :context_metadata, context_metadata_key: :meta

  # Same:
  # plugin :context_metadata
  # config.context_metadata.key = :meta
end

UserSerializer.to_h(nil, meta: { version: '1.0.1' })
# => {:data=>nil, :version=>"1.0.1"}
```

### Plugin :formatters

Allows to define `formatters` and apply them to attribute values.

Config option `config.formatters.add` can be used to add formatters.

Attribute option `:format` can be used with the name of formatter or with
callable instance.

Formatters can accept up to 2 parameters (formatted object, context)

```ruby
class AppSerializer < Serega
  plugin :formatters, formatters: {
    iso8601: ->(value) { time.iso8601.round(6) },
    on_off: ->(value) { value ? 'ON' : 'OFF' },
    money: ->(value, ctx) { value / 10**ctx[:digits) }
    date: DateTypeFormatter # callable
  }
end

class UserSerializer < Serega
  # Additionally, we can add formatters via config in subclasses
  config.formatters.add(
    iso8601: ->(value) { time.iso8601.round(6) },
    on_off: ->(value) { value ? 'ON' : 'OFF' },
    money: ->(value) { value.round(2) }
  )

  # Using predefined formatter
  attribute :commission, format: :money
  attribute :is_logined, format: :on_off
  attribute :created_at, format: :iso8601
  attribute :updated_at, format: :iso8601

  # Using `callable` formatter
  attribute :score_percent, format: PercentFormmatter # callable class
  attribute :score_percent, format: proc { |percent| "#{percent.round(2)}%" }
end
```

### Plugin :presenter

Moves computed attribute logic out of blocks and into a dedicated `Presenter` class,
keeping serializers readable as schemas rather than bags of lambdas.

Without the plugin, computed attributes live as inline blocks:

```ruby
class UserSerializer < Serega
  attribute :name, value: proc { |u| [u.first_name, u.last_name].compact.join(' ') }
  attribute :role, value: proc { |u, ctx| u == ctx[:current_user] ? :self : :other }
end
```

With the plugin, they move into a clean class:

```ruby
class UserSerializer < Serega
  plugin :presenter

  attribute :name
  attribute :role

  class Presenter
    def name
      [first_name, last_name].compact.join(' ')
    end

    def role
      id == __ctx__[:current_user_id] ? :self : :other
    end
  end
end
```

`Presenter` inherits from `SimpleDelegator`, so every method of the serialized
object is available directly inside presenter methods. Any method not explicitly
defined on `Presenter` is resolved via `method_missing` on the first call, which
also defines a real delegator method — so all subsequent serializations call it
directly, without going through `method_missing` again.

The original wrapped object is accessible via `__getobj__` (standard
`SimpleDelegator` API) when you need an unambiguous reference to it.

The serialization context is accessible via the private method `__ctx__`.

### Plugin :string_modifiers

Allows to specify modifiers as strings.

Serialized attributes must be split with `,` and nested attributes must be
defined inside brackets `()`.

Modifiers can still be provided the old way using nested hashes or arrays.

```ruby
PostSerializer.plugin :string_modifiers
PostSerializer.new(only: "id,user(id,username)").to_h(post)
PostSerializer.new(except: "user(username,email)").to_h(post)
PostSerializer.new(with: "user(email)").to_h(post)

# Modifiers can still be provided the old way using nested hashes or arrays.
PostSerializer.new(with: {user: %i[email, username]}).to_h(post)
```

### Plugin :if

Plugin adds `:if, :unless, :if_value, :unless_value` options to
attributes so we can remove attributes from the response in various ways.

Use `:if` and `:unless` when you want to hide attributes before finding
attribute value, and use `:if_value` and `:unless_value` to hide attributes
after getting the final value.

Options `:if` and `:unless` accept currently serialized object and context as
parameters. Options `:if_value` and `:unless_value` accept already found
serialized value and context as parameters.

Options `:if_value` and `:unless_value` cannot be used with the `:serializer` option.
Use `:if` and `:unless` in this case.

See also a `:hide` option that is available without any plugins to hide
attribute without conditions.
Look at [select serialized fields](#selecting-fields) for `:hide` usage examples.

```ruby
 class UserSerializer < Serega
   attribute :email, if: :active? # translates to `if user.active?`
   attribute :email, if: proc {|user| user.active?} # same
   attribute :email, if: proc {|user, ctx| user == ctx[:current_user]}
   attribute :email, if: CustomPolicy.method(:view_email?)

   attribute :email, unless: :hidden? # translates to `unless user.hidden?`
   attribute :email, unless: proc {|user| user.hidden?} # same
   attribute :email, unless: proc {|user, context| context[:show_emails]}
   attribute :email, unless: CustomPolicy.method(:hide_email?)

   attribute :email, if_value: :present? # if email.present?
   attribute :email, if_value: proc {|email| email.present?} # same
   attribute :email, if_value: proc {|email, ctx| ctx[:show_emails]}
   attribute :email, if_value: CustomPolicy.method(:view_email?)

   attribute :email, unless_value: :blank? # unless email.blank?
   attribute :email, unless_value: proc {|email| email.blank?} # same
   attribute :email, unless_value: proc {|email, context| context[:show_emails]}
   attribute :email, unless_value: CustomPolicy.method(:hide_email?)
 end
```

### Plugin :camel_case

By default, when we add an attribute like `attribute :first_name` it means:

- adding a `:first_name` key to the resulting hash
- adding a `#first_name` method call result as value

But it's often desired to respond with *camelCased* keys.
By default, this can be achieved by specifying the attribute name and method directly
for each attribute: `attribute :firstName, method: first_name`

This plugin transforms all attribute names automatically.
We use a simple regular expression to replace `_x` with `X` for the whole string.
We make this transformation only once when the attribute is defined.

You can provide custom transformation when adding the plugin,
for example `plugin :camel_case, transform: ->(name) { name.camelize }`

For any attribute camelCase-behavior can be skipped when
the `camel_case: false` attribute option provided.

This plugin transforms only attribute keys, without affecting the `root`,
`metadata` and `context_metadata` plugins keys.

If you wish to [select serialized fields](#selecting-fields), you should
provide them camelCased.

```ruby
class AppSerializer < Serega
  plugin :camel_case
end

class UserSerializer < AppSerializer
  attribute :first_name
  attribute :last_name
  attribute :full_name, camel_case: false,
    value: proc { |user| [user.first_name, user.last_name].compact.join(" ") }
end

require "ostruct"
user = OpenStruct.new(first_name: "Bruce", last_name: "Wayne")
UserSerializer.to_h(user)
# => {firstName: "Bruce", lastName: "Wayne", full_name: "Bruce Wayne"}

UserSerializer.new(only: %i[firstName lastName]).to_h(user)
# => {firstName: "Bruce", lastName: "Wayne"}
```

### Plugin :depth_limit

Helps to secure from malicious queries that serialize too much
or from accidental serializing of objects with cyclic relations.

Depth limit is checked when constructing a serialization plan, that is when
`#new` method is called, ex: `SomeSerializer.new(with: params[:with])`.
It can be useful to instantiate serializer before any other business logic
to get possible errors earlier.

Any class-level serialization methods also check the depth limit as they also
instantiate serializer.

When the depth limit is exceeded `Serega::DepthLimitError` is raised.
Depth limit error details can be found in the additional
`Serega::DepthLimitError#details` method

The limit can be checked or changed with the next config options:

- `config.depth_limit.limit`
- `config.depth_limit.limit=`

There is no default limit, but it should be set when enabling the plugin.

```ruby
class AppSerializer < Serega
  plugin :depth_limit, limit: 10 # set limit for all child classes
end

class UserSerializer < AppSerializer
  config.depth_limit.limit = 5 # overrides limit for UserSerializer
end
```

### Plugin :explicit_many_option

The plugin requires adding a `:many` option when adding relationships
(attributes with the `:serializer` option).

Adding this plugin makes it clearer to find if some relationship is an array or
a single object.

```ruby
  class BaseSerializer < Serega
    plugin :explicit_many_option
  end

  class UserSerializer < BaseSerializer
    attribute :name
  end

  class PostSerializer < BaseSerializer
    attribute :text
    attribute :user, serializer: UserSerializer, many: false
    attribute :comments, serializer: PostSerializer, many: true
  end
```

## Errors

- The `Serega::SeregaError` is a base error raised by this gem.
- The `Serega::AttributeNotExist` error is raised when validating attributes in
  `:only, :except, :with` modifiers. This error contains additional methods:

   - `#serializer` - shows current serializer
   - `#attributes` - lists not existing attributes

## Release

To release a new version, read [RELEASE.md](https://github.com/aglushkov/serega/blob/master/RELEASE.md).

## Development

- `bundle install` - install dependencies
- `bin/console` - open irb console with loaded gems
- `bundle exec rspec` - run tests
- `bundle exec rubocop` - check code standards
- `yard stats --list-undoc --no-cache` - view undocumented code
- `yard server --reload` - view code documentation

## Contributing

Bug reports, pull requests and improvements ideas are very welcome!

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

[activerecord_preloads]: #plugin-activerecord_preloads
[batch-loading]: #batch-loading
[camel_case]: #plugin-camel_case
[context_metadata]: #plugin-context_metadata
[depth_limit]: #plugin-depth_limit
[formatters]: #plugin-formatters
[metadata]: #plugin-metadata
[preloads]: #preloads
[presenter]: #plugin-presenter
[root]: #plugin-root
[string_modifiers]: #plugin-string_modifiers
[if]: #plugin-if
[build-badge]: https://github.com/aglushkov/serega/actions/workflows/main.yml/badge.svg?event=push
[build]: https://github.com/aglushkov/serega/actions/workflows/main.yml
