# Plugins

Plugins are opt-in extensions. Each plugin is loaded per serializer class and is inherited by subclasses. Load a plugin with `plugin :name` before defining attributes that use it.

```ruby
class AppSerializer < Serega
  plugin :formatters, formatters: { iso8601: ->(v) { v.iso8601 } }
  plugin :camel_case
  plugin :activerecord_preloads
end
```

## Plugin index

| Plugin | Description | Docs |
|---|---|---|
| `:activerecord_preloads` | Automatically preloads ActiveRecord associations before serialization | [activerecord_preloads.md](activerecord_preloads.md) |
| `:formatters` | Defines named value transformers applied to attributes via `:format` | [formatters.md](formatters.md) |
| `:if` | Conditionally includes or excludes attributes based on object or value | [if.md](if.md) |
| `:root` | Wraps serialized output in a root key | [root.md](root.md) |
| `:metadata` | Adds static or computed metadata to every response | [metadata.md](metadata.md) |
| `:context_metadata` | Lets callers pass metadata at serialization time, merged into the response | [context_metadata.md](context_metadata.md) |
| `:camel_case` | Transforms snake_case attribute names to camelCase keys in output | [camel_case.md](camel_case.md) |
| `:presenter` | Wraps each serialized object in a Presenter class | [presenter.md](presenter.md) |
| `:depth_limit` | Raises an error when serialization nesting exceeds a configured limit | [depth_limit.md](depth_limit.md) |
| `:string_modifiers` | Allows only/except/with modifiers as a comma-separated string | [string_modifiers.md](string_modifiers.md) |
| `:explicit_many_option` | Makes `:many` required on all attributes that use `:serializer` | [explicit_many_option.md](explicit_many_option.md) |
