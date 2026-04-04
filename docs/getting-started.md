# Getting Started

Install Serega, define your first serializer, and serialize an object.

## Install

Add Serega to your Gemfile:

```ruby
bundle add serega
```

## Minimal Example

```ruby
require "serega"
require "ostruct"

class AppSerializer < Serega
  # shared plugins and config go here
end

class UserSerializer < AppSerializer
  attribute :name
  attribute :email
end

user = OpenStruct.new(name: "Bruce", email: "bruce@example.com")

UserSerializer.to_h(user)
# => { name: "Bruce", email: "bruce@example.com" }

UserSerializer.to_h([user])
# => [{ name: "Bruce", email: "bruce@example.com" }]

UserSerializer.call(user)
# => { name: "Bruce", email: "bruce@example.com" }
```

## How It Works

**Define a base serializer.** Create a shared base class that all your serializers inherit from. This is where you configure plugins and default behavior once, and all child serializers inherit it automatically.

```ruby
class AppSerializer < Serega
  # All plugins and configuration here apply to every serializer that inherits from AppSerializer
  # plugin :camel_case
  # plugin :root
end
```

**Define a serializer with attributes.** Each attribute maps to a field in your JSON output. By default, an attribute reads a method or property with the same name from your object.

```ruby
class UserSerializer < AppSerializer
  attribute :name    # reads object.name
  attribute :email   # reads object.email
end
```

**Serialize an object.** Call `.call()` to convert a single object or an array of objects to a hash (or call `.to_h()` as an alias).

```ruby
user = OpenStruct.new(name: "Bruce", email: "bruce@example.com")

UserSerializer.to_h(user)
# => { name: "Bruce", email: "bruce@example.com" }

UserSerializer.to_h([user])
# => [{ name: "Bruce", email: "bruce@example.com" }]

UserSerializer.call(user)  # same as .to_h()
# => { name: "Bruce", email: "bruce@example.com" }
```

**Reuse a serializer instance.** Instead of creating a new serializer each time, instantiate it once if the modifiers (like `only:` or `except:`) stay the same. The serialization plan is prepared only once, making it faster for repeated calls.

```ruby
serializer = UserSerializer.new(only: [:name])
serializer.to_h(user1)   # fast
serializer.to_h(user2)   # fast - plan is already cached
```

## Next

→ [Attributes](attributes.md)
