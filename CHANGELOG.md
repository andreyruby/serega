# CHANGELOG

## [0.37.2] - 2026-07-08

- Fix error attribution for batch-loaded attributes (relations, `:preload`, and
  explicit `:batch`). Their values are resolved during the batch attach phase,
  which was not wrapping failures with the
  `(when serializing '<name>' attribute in <Serializer>)` details that inline
  attributes already got. The message (and the duplicated helper that produced it)
  is now shared between the serialization walk and the batch loader, so every
  attribute reports the same way.

- Auto-batched relations and preloads no longer register a synthetic per-attribute
  loader or build an identity hash that was never read. They are marked with a
  single reserved name that the batch loader skips, so their value still comes from
  the attribute's own resolver while objects are gathered and preloads run once per
  level. No behavior change.

## [0.37.1] - 2026-07-08

- Fix `:if_value`/`:unless_value` conditions on batch-loaded attributes leaving a
  `nil` value in the result instead of omitting the key. A batch attribute reserves
  its slot in the result hash before its value is known; when a value condition then
  hid the attribute, that reserved key was left behind with a `nil` value. The
  reserved key is now removed.

## [0.37.0] - 2026-07-08

- **BREAKING**: `config.hide_by_default` no longer accepts an Array of symbols.
  The Array form (`[:preload]`, `[:batch]`, `[:preload, :batch]`) is replaced by a
  single `:auto` symbol. The motivation: attributes with `:preload` are being
  auto-converted into batch-loaded attributes (see below), so the `:preload` and
  `:batch` distinction in the hide rule became meaningless — an attribute declared
  with `:preload` would end up with a batch loader too. `:auto` collapses both into
  one semantic: hide any attribute that requires deferred or lazy loading.
  `true` and `false` are unchanged.

  ```ruby
  # Before
  config.hide_by_default = [:preload, :batch]

  # After
  config.hide_by_default = :auto
  ```

- **BREAKING**: removed the public `Serega#preloads` method. Preloads are no longer
  exposed as a hash; `:preload` is used only by the `:activerecord_preloads`
  plugin, which loads the declared associations automatically.

- **BREAKING**: the attribute `:preload_path` option has been removed. It existed
  only to steer where nested preloads attached during the old deep merge; with
  per-level preloads there is nothing to disambiguate, so it is no longer needed.

- Serialization now routes every relation through the batch mechanism, giving one
  uniform execution path. The `:activerecord_preloads` plugin loads every
  declared association once, so there are no N+1 queries, while pure-ActiveRecord
  chains keep the same query counts. `config.hide_by_default = :auto` hides the
  same attributes as before (those declared with `:preload` or `:batch`).

- Fixed: a named batch loader shared by several attributes (`batch: { use: :name }`)
  is now called once per object set instead of once per attribute.

- Add the `preload_with` serializer class method — register a handler (a block or
  a callable taking `(objects, preloads)`) that performs the eager loading for
  attributes declared with `:preload`. This is the generic loading seam: the
  `:activerecord_preloads` plugin now registers a handler built on
  `ActiveRecord::Associations::Preloader`, other ORMs can register their own,
  and a handler is not limited to ORMs at all — it can load data from any source
  and attach it to plain non-ORM objects by its own rules. The handler is
  inherited by child serializers and can be overridden per subclass.

  ```ruby
  class AppSerializer < Serega
    preload_with { |objects, preloads| MyORM.preload(objects, preloads) }
  end
  ```

- `:preload` values are now passed to the preload handler exactly as written
  (Symbol, Array, Hash, or any custom value an ORM understands) instead of being
  normalized into a nested Hash. ActiveRecord accepts these directly, so AR query
  counts are unchanged.

- **BREAKING**: `preload: true` is now rejected when the attribute is defined.
  `false`/`nil` disable preloading; any other value is a preload spec; `true` is
  neither.

- **BREAKING**: declaring `:preload` (directly or via `auto_preload`) now requires
  a `preload_with` handler on that serializer. If none is registered, serializing
  raises a clear error instead of silently preloading nothing. Loading
  `:activerecord_preloads` registers the handler for you.

## [0.36.0] - 2026-05-12

- Add `.to_data` / `#to_data` — serialize objects to Ruby `Data` value objects.
  Nested serialized relations are recursively converted to `Data` objects.
  Plugin `:root` wraps the result in an outer `Data` with root and metadata keys.
  Plugin `:if` correctly builds `Data` classes from the actually-present keys when
  conditions skip some attributes.
- **BREAKING**: Raise minimum supported Ruby version to 3.2. The `Data` class
  introduced in Ruby 3.2 is required by the new `.to_data` feature. The existing
  `.to_h` serialization continues to work as before and has no such requirement,
  but we no longer test or support older Ruby versions.

## [0.35.0] - 2026-04-30

- Plugin `:presenter` — expose serialization context inside `Presenter` via `__ctx__`

## [0.34.0] - 2026-04-29

- Replace `config.auto_hide` with `config.hide_by_default`.
  Accepts `false` (default — nothing hidden), `true` (hide all attributes),
  or an array of symbols — `[:preload]`, `[:batch]`, or `[:preload, :batch]` —
  to hide only attributes that use those options.
  Attribute-level `hide: true/false` always takes precedence over the config.

## [0.33.2] - 2026-04-05

- Allow `true` as a modifier value (e.g. `only: { users: { first_name: true, posts: { text: true } } }`)

## [0.33.1] - 2025-09-18

- Fix returned nils for batch-loaded attributes (issue was that batch-load data was fetched for unique objects only)
- Replace Proc-based value resolvers with separate classes
- Eliminate extra method calls for new value resolvers

## [0.33.0] - 2025-08-20

- Add config `batch_id_option` method to set default method to resolve batch
  value. Previously it was `:id` hardcoded value. Now `:id` is a default value.
- Raname method to add named batch loader from `.batch_loader` to `.batch`
- Remove `to_json` and `as_json` methods and config options.
  After ruby JSON gem becomes faster in
  [2.8.0 version](https://github.com/ruby/json/releases/tag/v2.8.0),
  there are no sense to keep this functionality

## [0.32.0] - 2025-08-19

- Fix issue with `auto_preload` tries to preload association by attribute name
  instead of by `method` when `method` provided

## [0.31.0] - 2025-08-19

- Fix issue with `auto_preload` tries to preload associations for attributes
  with `batch` option

## [0.30.0] - 2025-08-18

### Breaking Changes

- **BREAKING**: Configuration changes
  Added options `auto_hide` and `auto_preload`

  **Before**

  ```ruby
  plugin :preloads,
    auto_preload_attributes_with_delegate: true,
    auto_preload_attributes_with_serializer: true,
    auto_hide_attributes_with_preload: true

  plugin :batch, auto_hide: true
  ```

  **After**

  ```ruby
  config.auto_hide = true
  config.auto_preload = true

  # Or you can specify specific options that trigher auto hide or preload:
  config.auto_hide = { has_preload_option: true, has_batch_option: true }
  config.auto_preload = { has_serializer_option: true, has_delegate_option: true }
  ```

- **BREAKING**: Removed `batch` plugin. There are new functionality called `batch loaders`
  integrated to core that replaces batch plugin.

  **Before**

  ```ruby
  attribute :foo, batch: { loader: FooLoader, id_method: :id }
  ```

  **After**

  ```ruby
  attribute :foo, batch: FooLoader                # id: :id (by default)
  attribute :foo, { use: FooLoader, id: :foo_id } # id: :foo_id
  attribute :foo, FooLoader, value: proc { |obj, batches:| batches[:foo][obj.id] } # custom value to resolve batch
  ```

- **BREAKING**: Moved preloads functionality from `:preloads` plugin to core.
  The `:preloads` plugin is no longer needed and should be removed from your
  serializers.

## [0.21.0] - 2024-11-19

- Allow to provide modifiers and serialization options as strings. Only symbols
  were allowed previously.

- Test compatibility with ActiveRecord 8.0.

## [0.20.1] - 2024-02-25

- Fix issue with :if plugin used together with :batch plugin.
  We kept `key => nil` attribute when key should have been skipped
  because of :if_value or :unless_value option

## [0.20.0] - 2023-12-29

- Validate plugins options keys
- Add additional methods to Serega::AttributeNotExist:

   - `#serializer` Shows current serializer;
   - `#attributes` Lists not existing attributes.

- Fix extra allocations by replacing forwardable methods with plain ruby methods

## [0.19.0] - 2023-12-17

- Added :default option for attributes. The `default` option value will replace
  nils. Also we will use empty array as a default when `many: true` is
  specified without custom :default option
- Remove :batch plugin :default option. It can be replaced with the new global
  :default option.

## [0.18.0] - 2023-11-11

- Rename batch plugin option `key` to `id_method`.
- Rename batch plugin init option `default_key` to `id_method`.
  Now it can be callable object
- Rename batch plugin config option `default_key` to `id_method`.
  Now it can be callable object

```ruby
class SomeSerializer < Serega
  # previously it was `default_key: :id`
  plugin :batch, id_method: :id

  # previously it was `config.batch.default_key = :id`
  config.batch.id_method = :id

  # previously it was `attribute :other, batch: {key: :other_id, loader: ...}`
  attribute :other, batch: {id_method: :other_id, loader: OtherLoader}
end
```

- Require named batch loaders to be defined before usage

```ruby
class AppSerializer < Serega
  plugin :batch, id_method: :id

  # Define named loader first
  config.batch.define(:posts_comments_counter) do |post_ids|
    Comment.where(post_id: post_ids).group(:post_id).count
  end
end

class PostSerializer < AppSerializer
  # Use it later
  attribute :comments_count, batch: { loader: :posts_comments_counter }
end
```

## [0.17.0] - 2023-11-03

- Allow to provide callable/lambdas objects with 0-2 args as attribute :value
  object
- Allow to provide callable/lambdas with 0-2 args format in :formatters plugin
- Allow to provide callable/lambdas with 0-2 args as :if plugin options
- Allow to provide callable/lambdas with 0-3 args as :batch plugin options
- Allow to provide callable :const and :value options to meta_attributes
  of `:metadata` plugin

```ruby
# Attributes with callable classes
attribute :email, value: EmailFetcher
attribute :email, if: EmailPolicy
attribute :email, batch: {key: EmailKeyFetcher, loader: EmailBatchLoader }
attribute :email, format: EmailFormatter
```

## [0.16.0] - 2023-10-15

- Add :depth_limit plugin that helps to secure from malicious queries that
  require to serialize too much or from accidental serializing of objects with
  cyclic relations
- Add :camel_case plugin to automatically transform attribute keys to camelCase
- Rename attribute option `:key` to `:method`
- Rename attribute `:delegate` sub-option `:key` to `:method`
- Validate there are no extra `:delegate` sub-options

## [0.15.0] - 2023-08-13

- Add validation that option :many can only be added only together with :serializer
  or :batch options, it is useless without them

- Remove :openapi plugin. It was wrong place to add this plugin.
  Serializers should be good at one thing - serialization.
  Serializers classes just don't know all needed context to build good schema.
  You can use this gist as an example how to build OpenAPI schema for Serega
  serializer for ActiveRecord objects: <https://gist.github.com/aglushkov/60e3ac1525a940cc6a144c92822556e5>

## [0.14.0] - 2023-07-24

- Add :explicit_many_option plugin
- Add '.openapi_properties' method to specify openapi_properties
- Remove :openapi attribute option from :openapi plugin (replaced with openapi_properties)

## [0.13.0] - 2023-07-20

- Add :openapi gem that helps to construct OpenAPI schema for serializer.
  It can help to construct response schemas and use with some OpenAPI tools
  (for example with rswag gem). Look at README for more information

## [0.12.0] - 2023-07-10

- Fix issue <https://github.com/aglushkov/serega/issues/85>
  With this issue fixed we now require to provide `:preload_path` attribute
  option when preloaded more than one association. Before this change we preload
  nested associations only to the latest specified association. Please see
  README `preload` plugin section for more details.

## [0.11.2] - 2023-04-30

- Raise meaningful error when :batch plugin not enabled for root serializer.
  Workaround for issue <https://github.com/aglushkov/serega/issues/94> - it is
  not a bug, it is how `batch` plugin works.

```ruby
# Before:
# => NoMethodError:
#    undefined method get for nil:NilClass in
#    remember_key_for_batch_loading method
#
# After:
# => Serega::SeregaError:
#    Plugin :batch must be added to current serializer (#{current_serializer})
#    to load attributes with :batch option in nested serializer
#    (#{nested_serializer})
#
```

## [0.11.1] - 2023-04-25

- Fix :default_key batch plugin option was set to nil when defined as
  `plugin :batch, default_key: :id`

## [0.11.0] - 2023-04-24

### Breaking changes

- Rename `SeregaMap` class to `SeregaPlan` and `SeregaMapPoint` to `SeregaPlanPoint`
- Rename config option from `max_cached_map_per_serializer_count` to
  `max_cached_plans_per_serializer_count`
- Rename config method from `config.batch_loaders` to `config.batch.loaders`
- Rename config method from `config.batch_loaders.define` to `config.batch.define`

### Improvements

- Add config method `config.batch.auto_hide=(bool)` to automatically mark as
  hidden attributes having :batch option
- Allow to define :batch plugin with :auth_hide option
- Allow to define :batch plugin with :default_key option

```ruby
class SomeSerializer < Serega
  plugin :batch, auto_hide: true, default_key: :id

  # or
  plugin :batch
  config.batch.auto_hide = true
  config.batch.default_key = :id
end
```

- Add `config.delegate_default_allow_nil=(bool)` config option to specify
  default behavior when delegated object is nil. By default it is `false`

```ruby
class SomeSerializer < Serega
  config.delegate_default_allow_nil = true
end
```

## [0.10.0] - 2023-03-28

- Less strict attribute name format. Allow attribute names to include chars
  "\_", "-" and "~". They can be added as first or last characters also.
- Allow to disable attribute name format check globally or per-serializer via:

```ruby
Serega.config.check_attribute_name = false

class SomeSerializer < Serega
  config.check_attribute_name = false
end
```

- Added comments in code about where each methods extended
- Allow to load :if plugin and :batch plugin in any order
- Less objects allocations when parsing string modifiers

## [0.9.0] - 2023-03-23

- Plugin `:if` was added, look at README.md for all options and examples.
- Plugin `:hide_nil` was removed, but it can be replaced by plugin `:if`

```ruby
# previously
plugin :hide_nil
attribute :email, hide_nil: true

# now
plugin :if
attribute :email, unless_value: :nil?
```

## [0.8.3] - 2023-02-14

- Allow to call serialize methods with `nil` as options

```ruby
  UserSerialzier.to_h(user, nil) # same as UserSerialzier.to_h(user)
  UserSerialzier.new(nil).to_h(user, nil)  # same as UserSerialzier.new.to_h(user)
```

- Optimize allocations
- Add documentation coverage checks in RELEASE.md
- Add allocate_stats gem to easily check extra allocations

## [0.8.2] - 2022-12-20

- Show current serializer and attribute when NoMethodError happens
- Fix auto preload, that should not be added for attributes with
  :serializer and :batch options

## [0.8.1] - 2022-12-11

- Change requested fields validation message. Now we return all not existing
  fields instead of first one.

## [0.8.0] - 2022-12-09

- Add `:key` option to `:delegate` option. Remove possibility to add top-level
  `:key` option together with `:delegate` option

```ruby
  # BEFORE
  attribute :is_presale, delegate: { to: :product }, key: :presale?

  # NOW
  attribute :is_presale, delegate: { to: :product, key: :presale? }
```

## [0.7.0] - 2022-12-08

- Root plugin now does not symbolize provided root key
- Root plugin now allows to provide `nil` root to skip adding root
- Metadata and context_metadata plugins now raise error if root plugin was not
  added before manually
- Metadata and context_metadata not added if root is nil
- More documentation with yardoc
- Require :preloads plugin to be added manually before :activerecord_preloads

## [0.6.1] - 2022-12-03

- Fix `presenter` plugin was not working for nested serializers
- Fix issue with not auto-preloaded relations when using #call method
- Remove SeregaSerializer class, moved its functionality to Serega#serialize
  method

## [0.6.0] - 2022-12-01

- Make batch loader to accept current point instead of nested points as 3rd
  parameter.

  It becomes easier to find preloads by asking `point.preloads`

## [0.5.2] - 2022-11-21

- Change gem description again

## [0.5.1] - 2022-11-21

- Change gem summary, description, changelog link
- Fix README links

## [0.5.0] - 2022-11-21

- Add plugin :batch for batch loading

```ruby
  class PostSerializer < Serega
    plugin :batch

    # Define batch loader via callable class, it must accept three args
    # (keys, context, nested_attributes)
    attribute :comments_count,
      batch: { key: :id, loader: PostCommentsCountBatchLoader, default: 0}

    # Define batch loader via Symbol, later we should define this loader via
    # config.batch_loaders.define(:posts_comments_counter) { ... }
    attribute :comments_count,
      batch: { key: :id, loader: :posts_comments_counter, default: 0}

    # Define batch loader with serializer
    attribute :comments,
      serializer: CommentSerializer,
      batch: { key: :id, loader: :posts_comments, default: []}

    # Resulted block must return hash like { key => value(s) }
    config.batch_loaders.define(:posts_comments_counter) do |keys|
      Comment.group(:post_id).where(post_id: keys).count
    end

    # We can return objects that will be automatically serialized if attribute
    # defined with :serializer
    #
    # Parameter `context` can be used when loading batch
    # Parameter `points` can be used to find nested attributes that will be serialized
    config.batch_loaders.define(:posts_comments) do |keys, context, points|
      Comment.where(post_id: keys).where(is_spam: false).group_by(&:post_id)
    end
  end
```

## [0.4.0] - 2022-09-20

- Allow to provide formatters config when adding `formatters` plugin

```ruby
  plugin :formatters, formatters: {
    iso8601: ->(value) { time.iso8601.round(6) },
    on_off: ->(value) { value ? 'ON' : 'OFF' },
    money: ->(value) { value.round(2) }
  }
```

## [0.3.0] - 2022-08-10

- Use Oj JSON adapter by default if Oj is loaded. We use `mode: :compat` when
  serializing objects. Config can still be overwritten:

```ruby
 config.to_json = proc { |data| Oj.dump(mode: :strict) }
 config.from_json = proc { |json| Oj.load(json) }
```

- We can now access config options through methods instead of hash keys

```ruby
# Shows enabled plugins
config.plugins

# Shows allowed options keys when initiating serializer
config.initiate_keys

# Shows allowed options keys when adding new attribute
config.attribute_keys

# Shows allowed options keys when serializing object with
 #call, #to_h, #to_json, #as_json methods
config.serialize_keys

# Shows value of check_initiate_params option. Default is true
config.check_initiate_params

# Changes check_initiate_params option. When value is false - it skips invalid
# initiate options and values
config.check_initiate_params=(bool_value)

# Shows count of cached maps per serializer. Default is 0
config.max_cached_map_per_serializer_count

# Changes count of cached maps
config.max_cached_map_per_serializer_count=(int_value)

# Returns Proc that is used to generate JSON. By default uses `JSON.dump` method
config.to_json

# Changes proc to generate JSON.
config.to_json=(proc_value)

# Returns Proc that is used to parse JSON. By default uses `JSON.load` method
config.from_json

# Changes proc to parse JSON.
config.from_json=(proc_value)

# With context_metadata plugin:
# Key used to add metadata. By default it is :meta
config.context_metadata.key

# Changes key used to add context_metadata
config.context_metadata.key=(value)

# With formatters plugin:
# Add formatters
config.formatters.add(key => proc_value)

# With metadata plugin:
# Shows allowed attributes keys when adding meta_attribute
config.metadata.attribute_keys

# With preloads plugin:
# Shows this config value. Default is false
config.preloads.auto_preload_attributes_with_delegate

# Shows this config value. Default is false
config.preloads.auto_preload_attributes_with_serializer

# Shows this config value. Default is false
config.preloads.auto_hide_attributes_with_preload

# Changes value
config.preloads.auto_preload_attributes_with_delegate=(bool)

# Changes value
config.preloads.auto_preload_attributes_with_serializer=(bool)

# Changes value
config.preloads.auto_hide_attributes_with_preload=(bool)

# With root plugin
# Shows current root config value. By default it is `{one: "data", many: "data"}`
config.root

# Changes root values.
config.root=(one:, many:)

# Shows root value used when serializing single object
config.root.one

# Shows root value used when serializing multiple objects
config.root.many

# Changes root value for serializing single object
config.root.one=(value)

# Changes root value for serializing multiple objects
config.root.many=(value)
```

- Added `from_json` config method that is used in `#as_json` result.
  It can be overwritten this way:

```ruby
config.from_json = proc {...}
```

- Configured branch coverage checking

- Disabling caching of serialized attributes maps by default. This can be
  reverted with `config.max_cached_map_per_serializer_count = 50`

- Refactor validations. Remove `validate_modifiers` plugin. Modifiers are now
  validated by default. This can be changed globally with config option
  `config.check_initiate_params = false`. Or we can skip validation per
  serialization

```ruby
SomeSerializer.
  (obj, only: ..., :with: ..., except: ..., check_initiate_params: false)
```

## [0.2.0] - 2022-08-01

- Remove `.relation` DSL method for simplicity. Just use
  `attribute :foo, serializer: Foo`. Method can be added back manually:

```ruby
  class Serega
    def self.relation(name, serializer:, **opts, &block)
      attribute(name, serializer: serializer, **opts, &block)
    end
  end
```

- Add config option for `:preload` plugin -
  `auto_preload_attributes_with_delegate`

```ruby
# Setup:
class Serega
  plugin :preload, auto_preload_attributes_with_delegate: true

  # or
  plugin :preload
  config[:preload][:auto_preload_attributes_with_delegate] = true
end
```

- Add option :delegate when defining attributes. Examples:

```ruby
  attribute :comments_count,
    delegate: { to: :user_stat }

  attribute :address_line_1, key: :line_1,
    delegate: { to: :address, allow_nil: true }
```

- Prohibit to use option :preload together with option :const (#23)

- Rename constants. Add prefix Serega for come classes.
  Previously in applications that use same class names this classes have to be
  defined with two colons "::".

   - Serega::Attribute -> Serega::SeregaAttribute
   - Serega::Convert -> Serega::SeregaConvert
   - Serega::ConvertItem -> Serega::SeregaConvertItem
   - Serega::Error -> Serega::SeregaError
   - Serega::Helpers -> Serega::SeregaHelpers
   - Serega::Map -> Serega::SeregaMap
   - Serega::Utils -> Serega::SeregaUtils
   - Serega::Validations -> Serega::SeregaValidations

## [0.1.5] - 2022-07-27

- Added config option `config[:preloads][:auto_hide_attributes_with_preload]`
  to `preloads` plugin. By default it is `false`.

- Plugin `validate_modifiers` now raises `Serega:AttributeNotExist` error when
  requested attribute not exists

- Change `preloads` plugin config option
  `config[:preloads][:auto_preload_relation] = true` to
  `config[:preloads][:auto_preload_attributes_with_serializer] = false`,
  so now there are no surprises where this preloads come from.

## [0.1.4] - 2022-07-25

- Fix context_metadata plugin error

```ruby
  wrong number of arguments (given 2, expected 1)
```

## [0.1.3] - 2022-07-25

- Fix activerecord_preloads plugin error

```ruby
  wrong number of arguments (given 2, expected 1)
```

## [0.1.2] - 2022-07-24

- Added :const attribute option to specify attribute with constant value

- Added `.call` and `#call` methods same as `.to_h` and `#to_h`. New methods
  were added as when we can serialize list of objects the result will be array,
  so `to_h` is a bit confusing

## [0.1.1] - 2022-07-13

- Fix validation and README docs about attribute option `:key`.
  Previously we validate option :method instead

## [0.1.0] - 2022-07-07

- Initial public release ([@aglushkov][])

[@aglushkov]: https://github.com/aglushkov
