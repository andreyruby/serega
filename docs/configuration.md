# Configuration

Configuration options control serialization behavior globally for a serializer class and are inherited by subclasses.

## Setting Configuration

Configuration is set on the serializer class using the `config` method. These settings apply to all instances of that serializer and can be inherited by subclasses:

```ruby
class AppSerializer < Serega
  config.auto_preload = true
  config.auto_hide = true
  config.max_cached_plans_per_serializer_count = 50
end

class UserSerializer < AppSerializer
  # Inherits all config from AppSerializer
  
  # Override just this one option
  config.check_initiate_params = false
end
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `auto_preload` | `false` | Auto-add `:preload` to attributes with `:delegate` or `:serializer` option. Accepts `true`, `false`, or `{ has_delegate_option: bool, has_serializer_option: bool }` |
| `auto_hide` | `false` | Auto-hide attributes with `:preload` or `:batch` option (they must be explicitly requested). Accepts `true`, `false`, or `{ has_preload_option: bool, has_batch_option: bool }` |
| `batch_id_option` | `:id` | Default method called on objects to get their id for batch loading |
| `check_initiate_params` | `true` | Raise `Serega::AttributeNotExist` when unknown attributes are passed in `only/except/with` |
| `check_attribute_name` | `true` | Validate attribute name characters (only `a-z A-Z 0-9 _ - ~` allowed) |
| `delegate_default_allow_nil` | `false` | Allow nil when using `:delegate` (globally) |
| `max_cached_plans_per_serializer_count` | `0` (disabled) | Cache serialization plans for reuse when same modifiers are used repeatedly. Stores up to N plans |

## Examples

### auto_preload

Automatically add `:preload` to attributes that use `:delegate` or `:serializer` options. This helps avoid N+1 queries by signaling that these associations should be preloaded.

```ruby
class UserSerializer < Serega
  config.auto_preload = true
  
  attribute :id
  attribute :name
  attribute :posts, serializer: PostSerializer  # preload auto-added
  attribute :author_name, delegate: {to: :author, attr: :name}  # preload auto-added
end

# Or with selective control:
config.auto_preload = {
  has_delegate_option: true,      # auto-preload :delegate attributes
  has_serializer_option: false    # don't auto-preload :serializer attributes
}
```

### auto_hide

Automatically hide attributes that have `:preload` or `:batch` options. These attributes must be explicitly requested via the `with` modifier.

```ruby
class UserSerializer < Serega
  config.auto_hide = true
  
  attribute :id
  attribute :name
  attribute :posts, serializer: PostSerializer, preload: :posts  # hidden by default
  attribute :comments_count, batch: :comments_count              # hidden by default
end

# Only include hidden attributes when requested
UserSerializer.new(with: :posts).to_h(user)

# Or with selective control:
config.auto_hide = {
  has_preload_option: true,   # hide attributes with :preload
  has_batch_option: false     # don't hide attributes with :batch
}
```

### batch_id_option

Set the method used to retrieve an object's id for batch loading. By default, `:id` is used.

```ruby
class CustomIdSerializer < Serega
  config.batch_id_option = :uuid  # Use :uuid instead of :id
  
  attribute :uuid
  attribute :name
end
```

### check_initiate_params

Control whether to raise an error when unknown attributes are passed to `only`, `except`, or `with` modifiers.

```ruby
class StrictSerializer < Serega
  config.check_initiate_params = true  # Default - raises error on unknown attributes
  
  attribute :id
  attribute :name
end

# This raises Serega::AttributeNotExist
StrictSerializer.new(only: :invalid).to_h(user)

# Disable to silently ignore unknown attributes
class PermissiveSerializer < Serega
  config.check_initiate_params = false
end

# No error - :invalid is silently ignored
PermissiveSerializer.new(only: :invalid).to_h(user)
```

### check_attribute_name

Validate that attribute names only contain allowed characters (a-z, A-Z, 0-9, _, -, ~).

```ruby
class ValidatedSerializer < Serega
  config.check_attribute_name = true  # Default - validates names
  
  attribute :id           # OK
  attribute :user_name    # OK
  attribute :"user-id"    # OK
  # attribute :"user@name" # Would raise an error
end

# Disable validation if needed
class NoValidationSerializer < Serega
  config.check_attribute_name = false
  
  attribute :"user@name"   # Allowed when validation is disabled
end
```

### delegate_default_allow_nil

Allow `nil` values when using the `:delegate` option. When `false` (default), delegated attributes that receive `nil` will raise an error.

```ruby
class User
  attr_accessor :profile
end

class UserSerializer < Serega
  config.delegate_default_allow_nil = false  # Default - raises error on nil
  
  attribute :name, delegate: {to: :profile, attr: :name}
end

user = User.new
user.profile = nil
UserSerializer.new.to_h(user)  # Raises error

# Allow nil values
class PermissiveUserSerializer < Serega
  config.delegate_default_allow_nil = true
  
  attribute :name, delegate: {to: :profile, attr: :name}
end

PermissiveUserSerializer.new.to_h(user)  # Returns {name: nil}
```

### max_cached_plans_per_serializer_count

Cache serialization plans for performance when the same modifiers are used repeatedly. Set to `0` (default) to disable caching.

```ruby
class UserSerializer < Serega
  config.max_cached_plans_per_serializer_count = 50  # Cache up to 50 plans
  
  attribute :id
  attribute :name
  attribute :email
  attribute :posts, serializer: PostSerializer
end

# First call - plan is built and cached
UserSerializer.new(only: [:id, :name]).to_h(user)

# Second call with same modifiers - uses cached plan for faster serialization
UserSerializer.new(only: [:id, :name]).to_h(user)

# Different modifiers - new plan is built and cached (up to the limit)
UserSerializer.new(only: [:id, :email]).to_h(user)
```

## Next Steps

→ [Plugins](plugins/README.md)
