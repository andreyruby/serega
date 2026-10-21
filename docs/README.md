# Serega Guides

Each guide covers one feature in depth. For a one-page overview of every option,
see the [Cheatsheet](../CHEATSHEET.md).

## Basics

- [Attributes](attributes.md) — define serializers, attributes and relations
- [Serializing](serializing.md) — `to_h`, `to_struct`, `to_data`
- [Selecting Fields](selecting-fields.md) — `:only`, `:except`, `:with`
- [Context](context.md) — pass `current_user` and other request data
- [Conditional Attributes](conditional-attributes.md) — `:if`, `:unless`,
  `:if_value`, `:unless_value`
- [Formatters](formatters.md) — format dates, money and other values

## Loading data without N+1

- [Preloads](preloads.md) — preload associations used by requested fields
- [Batch Loading](batch-loading.md) — load data for all serialized objects at once

## Data sources

- [Hash Records](hash-records.md) — read attribute values from Hash keys
- [Prepare Initial Objects](prepare-initial-objects.md) — serialize records by ids
- [Presenter](presenter.md) — write computed attributes as methods

## Advanced

- [Configuration](configuration.md) — all config options
- [Ractors](ractors.md) — serialize in parallel Ractors
- [Plugins](plugins.md) — `activerecord_preloads`, `string_modifiers`, `root`,
  `metadata`, `camel_case` and others
- [Errors](errors.md) — errors Serega raises
