# Serega Documentation

## Core

- [Getting Started](getting-started.md) — install, base serializer, first serialization call
- [Attributes](attributes.md) — all attribute options
- [Selecting Fields](selecting-fields.md) — only, except, with modifiers
- [Batch Loading](batch-loading.md) — load related data in groups
- [Preloads](preloads.md) — how preload tracking works
- [Configuration](configuration.md) — all config options reference

## Plugins

- [activerecord_preloads](plugins/activerecord_preloads.md) — automatic AR association preloading
- [formatters](plugins/formatters.md) — transform attribute values
- [if](plugins/if.md) — conditional attributes
- [root](plugins/root.md) — wrap responses in a root key
- [metadata](plugins/metadata.md) — add static metadata to responses
- [context_metadata](plugins/context_metadata.md) — add per-request metadata
- [camel_case](plugins/camel_case.md) — automatic camelCase keys
- [presenter](plugins/presenter.md) — encapsulate attribute logic in a Presenter class
- [depth_limit](plugins/depth_limit.md) — protect against deeply nested queries
- [string_modifiers](plugins/string_modifiers.md) — pass only/except/with as a single string
- [explicit_many_option](plugins/explicit_many_option.md) — require :many on all relationships

## Learning Path

New to Serega? Start with **Getting Started**, then work through **Attributes** and **Selecting Fields** to understand core concepts. Once you're comfortable with the basics, explore **Batch Loading** and **Preloads** to optimize your serialization. Finally, review **Configuration** for project-wide settings, and dive into **Plugins** to extend Serega with the features your application needs.
