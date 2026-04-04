# Selecting Fields

By default, all visible attributes are serialized. Use modifiers to select a subset.

## Problem

When you define attributes in a serializer, all of them (except those marked `hide: true`) appear in the output by default. This works for simple cases, but often you need finer control — serialize fewer fields for performance, exclude sensitive data, or conditionally include hidden attributes.

---

## Three Modifiers

### `:only` — serialize only the listed attributes

Include only the specified attributes in the output. All other attributes are excluded.

```ruby
UserSerializer.to_h(user, only: [:name, :email])
# => { name: "Bruce", email: "bruce@example.com" }
```

### `:except` — serialize all attributes except the listed ones

Include all attributes except the specified ones.

```ruby
UserSerializer.to_h(user, except: [:email])
# => { name: "Bruce" }
```

### `:with` — add hidden attributes to the output

By default, attributes defined with `hide: true` are not serialized. Use `:with` to conditionally include them.

```ruby
# Given: attribute :token, hide: true
UserSerializer.to_h(user, with: [:token])
# => { name: "Bruce", email: "bruce@example.com", token: "abc123" }
```

---

## Modifier Format

Modifiers accept **Hash**, **Array**, **Symbol**, or **String** (with the `string_modifiers` plugin).

### Array and Symbol

The simplest format — pass an array of attribute names, or a single symbol:

```ruby
only: [:name, :email]
only: :name
except: [:email]
with: [:token]
```

### Hash — target nested serializers

When an attribute uses a nested serializer, pass a Hash to apply modifiers to that nested serializer:

```ruby
# Only include name and posts (but only with title)
UserSerializer.to_h(user, only: [:name, { posts: [:title] }])
# => { name: "Bruce", posts: [{ title: "Hello" }] }

# Include all but exclude body from posts
UserSerializer.to_h(user, except: { posts: [:body] })
# => { name: "Bruce", email: "bruce@example.com", posts: [{ title: "Hello" }] }
```

Combine these in any nested structure:

```ruby
UserSerializer.to_h(user, only: { posts: { comments: [:text] } })
```

### String format

With the `string_modifiers` plugin, pass a comma-separated string with nested attributes in parentheses. This is useful for accepting field selection from GET query parameters:

```ruby
plugin :string_modifiers

UserSerializer.new(only: "name,posts(title)").to_h(user)
UserSerializer.new(except: "email,posts(body)").to_h(user)
```

See [string_modifiers plugin](plugins/string_modifiers.md) for full details.

---

## Error on Unknown Attribute

When a non-existing attribute is requested, `Serega::AttributeNotExist` is raised by default:

```ruby
UserSerializer.to_h(user, only: [:name, :typo])
# => Serega::AttributeNotExist
```

The exception provides:
- `#serializer` — the serializer where the unknown attribute was requested
- `#attributes` — list of unknown attribute names

### Disable the check

Per-serialization:

```ruby
UserSerializer.to_h(user, only: [:name, :typo], check_initiate_params: false)
```

Or globally in config:

```ruby
config.check_initiate_params = false
```

---

## Example

For a working example with hidden attributes, see `examples/hide_attributes.rb` in the repository.

---

→ Next: [Batch Loading](batch-loading.md)
