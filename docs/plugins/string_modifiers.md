# Plugin :string_modifiers

Allows `only`, `except`, and `with` modifiers to be supplied as a single comma-separated string instead of an array or hash.

## When to use

- Field selection comes from GET query parameters (e.g. `?only=id,name,posts(title,body)`).
- You want to avoid manually parsing query strings into nested hashes.
- You still need hash/array format to work alongside string format.

## Setup

```ruby
class AppSerializer < Serega
  plugin :string_modifiers
end
```

## Usage

```ruby
# String format
UserSerializer.new(only: "id,name,posts(title,body)").to_h(user)
UserSerializer.new(except: "email,posts(body)").to_h(user)
UserSerializer.new(with: "email").to_h(user)

# Hash/Array format still works unchanged
UserSerializer.new(only: { posts: %i[title body] }).to_h(user)
```

## String format

- Attribute names are separated by commas.
- Nested attributes are enclosed in parentheses immediately after the relationship name: `posts(title,body)`.
- Nesting can be arbitrarily deep: `posts(comments(author(name)))`.

---

**Next:** [explicit_many_option](explicit_many_option.md)
