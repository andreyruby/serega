# Attributes

Every field in a Serega serializer is an attribute. This page covers all available options.

Attributes define what *can* be serialized. What actually appears in the output is controlled by [modifiers](selecting-fields.md) at serialization time.

---

## Attribute name validation

Attribute names may only contain `a-z`, `A-Z`, `0-9`, `_`, `-`, `~` characters. This restriction exists so attribute names can be used in URLs without escaping.

To disable the check:

```ruby
config.check_attribute_name = false
```

---

## Options reference

### (no option) — method of same name

With no options, Serega calls the method matching the attribute name on the serialized object.

```ruby
attribute :first_name   # calls user.first_name
```

---

### `:method` — call a different method

When the attribute name and the object's method name differ, use `:method` to specify which method to call.

```ruby
attribute :first_name, method: :old_first_name   # calls user.old_first_name
```

---

### block — compute value inline

Pass a block to compute the attribute value. The block receives the object, or both the object and context.

```ruby
attribute(:full_name) { |user| "#{user.first_name} #{user.last_name}" }
attribute(:email) { |user, ctx| user.email if ctx[:current_user] == user }
```

---

### `:value` — Proc or callable object

Use `:value` when you want to pass a Proc or a callable object (anything responding to `#call`) instead of a block.

```ruby
attribute :first_name, value: proc { |user| user.profile&.first_name }
attribute :first_name, value: SomeCallableClass.new   # must respond to #call
```

---

### `:delegate` — read from a sub-object

Delegates attribute resolution to a nested object. By default, raises an error if the sub-object is nil.

```ruby
attribute :first_name, delegate: { to: :profile }
attribute :first_name, delegate: { to: :profile, method: :fname }   # calls user.profile.fname
attribute :first_name, delegate: { to: :profile, allow_nil: true }  # returns nil if profile is nil
```

The global default for `allow_nil` is `false`. Override it per-serializer with:

```ruby
config.delegate_default_allow_nil = true
```

---

### `:const` — always return a fixed value

The attribute always returns the given value, regardless of the serialized object.

```ruby
attribute :type, const: "user"
```

---

### `:default` — replace nil return values

When the resolved value is `nil`, the default is returned instead. Works with any type — empty string, `false`, `0`.

```ruby
attribute :first_name, default: ""
attribute :is_active, default: false
attribute :score, default: 0
```

---

### `:hide` — exclude from output by default

The attribute is defined but not included in serialization output unless explicitly requested with the `with:` modifier.

```ruby
attribute :token, hide: true
```

To include it:

```ruby
UserSerializer.to_h(user, with: [:token])
```

---

### `:serializer` — nested serializer

Marks an attribute as a relationship and specifies which serializer handles the nested object(s). Accepts a class, a String, or a Proc. Use String or Proc to avoid circular reference issues when two serializers reference each other.

```ruby
attribute :posts, serializer: PostSerializer
attribute :posts, serializer: "PostSerializer"       # resolved lazily by constant lookup
attribute :posts, serializer: -> { PostSerializer }  # resolved lazily via proc
```

---

### `:many` — explicit has-many flag

Controls whether the attribute value is treated as a collection. Optional — if omitted, Serega auto-detects by checking `object.is_a?(Enumerable)` at serialization time.

```ruby
attribute :posts, serializer: PostSerializer, many: true
attribute :profile, serializer: ProfileSerializer, many: false
```

When `many: true`, the default value changes from `nil` to `[]`.

`Struct` objects are `Enumerable`, so for Struct-backed associations always pass `many: false` explicitly:

```ruby
attribute :address, serializer: AddressSerializer, many: false
```

---

### `:preload` — declare association dependencies

Declares which association(s) this attribute depends on. Serega collects these declarations from all selected attributes and merges them into a single preloads hash, accessible via `serializer_instance.preloads`.

This option does **not** load anything by itself. Loading is handled separately — by the `activerecord_preloads` plugin or your own code.

```ruby
attribute :posts, serializer: PostSerializer, preload: :posts
attribute(:email, preload: :emails) { |user| user.emails.find(&:verified?) }
```

See [Preloads](preloads.md) for how to use the collected hash.

---

### `:preload_path` — path to nested preload target

When an attribute's value is resolved through an intermediate association (not directly on the serialized object), `:preload_path` specifies the path to the object that should receive nested preloads.

```ruby
attribute :image,
  preload: { attachment: :blob },
  preload_path: [:attachment],
  serializer: ImageSerializer,
  value: proc { |record| record.attachment }
```

Without `:preload_path`, any nested preloads from `ImageSerializer` would be merged at the root level. With it, they are nested under `:attachment`.

---

### `:batch` — batch loader configuration

Enables batch loading for the attribute. Batch loading groups resolution across multiple objects to avoid N+1 queries.

```ruby
attribute :comments_count, batch: { use: :comments_count, id: :id }
attribute :comments_count, batch: true   # uses attribute name as loader key; id method defaults to config.batch_id_option (:id)
```

See [Batch Loading](batch-loading.md) for the full API, including defining named loaders and custom callables.

---

### `:format` — transform the attribute value

Applies a named formatter or inline Proc to the resolved value. Requires the `formatters` plugin.

```ruby
attribute :created_at, format: :iso8601
attribute :score, format: proc { |v| "#{v.round(2)}%" }
attribute :score, format: PercentFormatter   # callable class
```

See [formatters](plugins/formatters.md) for setup and defining named formatters.

---

### `:if`, `:unless`, `:if_value`, `:unless_value` — conditional inclusion

Controls whether the attribute key and value appear in the output based on a condition. Requires the `if` plugin.

```ruby
attribute :email, if: :active?
attribute :email, if_value: :present?
```

See [if](plugins/if.md) for the full set of options and examples.

---

→ Next: [Selecting Fields](selecting-fields.md)
