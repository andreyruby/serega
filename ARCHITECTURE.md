# Architecture

How Serega serializes objects.

## Serialization flow

Serialization has three stages. Each stage lives for a different time.

```
Definition   once per serializer class   Serega, SeregaAttribute, SeregaBatchLoader
     ↓
Plan         once per set of modifiers   SeregaPlan → SeregaPlanPoint, SeregaResultBuilder per mode
     ↓
Run          once per serialization      SeregaEngine::Run → SeregaObjectGroup per plan
```

### 1. Definition

`attribute`, `batch` and `plugin` calls on a serializer class make the definition:

- `SeregaAttribute` (`lib/serega/attribute.rb`): name, options and a value resolver from `lib/serega/attribute_value_resolvers/`. `#value(object, context, batches:)` reads the value of one object.
- `SeregaBatchLoader` (`lib/serega/batch_loader.rb`): a named block that loads values of many objects in one call.

The first plan locks the class. Later definition calls raise.

### 2. Plan

`UserSerializer.new(only:, except:, with:)` gets a `SeregaPlan` from `SeregaPlanCache`.

- `SeregaPlan` (`lib/serega/plan.rb`): the attributes to serialize, as `SeregaPlanPoint`s, in definition order. `SeregaAttribute#visible?` selects them.
- `SeregaPlanPoint` (`lib/serega/plan_point.rb`): one attribute in a plan. A relation point has a `child_plan` for the relation serializer. The point runs the preloads (`#run_preloads`) and loads its batches (`#load_batches`).
- `SeregaResultBuilder` (`lib/serega/result_builder.rb`): makes the empty result containers of a plan in one mode: `{}` for `:hash` and `:data`, and a `Struct` for `:struct`.

### 3. Run

`to_h`, `to_data` and `to_struct` (`lib/serega.rb`) do these steps:

1. `normalize_serialization_opts` validates the options and sets `opts[:context]`.
2. `prepare_objects` calls the `prepare_initial_objects` handler.
3. `prepare_initial_serialization_opts` sets `opts[:run]`, `opts[:many]` and `opts[:plan]`.
4. `serialize` calls `opts[:run].call(plan, object, many:)`.
5. `to_data` converts the Hash results to `Data` objects with `SeregaDataBuilder`.

`SeregaEngine::Run` (`lib/serega/engine/run.rb`) is one serialization. It has the mode, the context, and one `SeregaObjectGroup` per plan:

```
run.call(plan, object, many:)
├─ run.object_group(plan).add(object, many)     → empty container(s), the result
└─ for each object group, also groups added during this loop
   └─ object_group.serialize
      └─ for each plan point
         ├─ point.run_preloads(objects)          once per group
         ├─ point.load_batches(object_group)     once per group
         ├─ child_group = run.object_group(point.child_plan)    relation points only
         └─ serialize_point
            └─ for each object
               ├─ value = attribute.value(object, context, batches:)
               ├─ relation: value = child_group.add(value, point.many)
               └─ containers[index][name] = value
```

`SeregaObjectGroup` (`lib/serega/object_group.rb`) holds all objects of one plan in one run, and a result container per object.

- `#add` wraps the objects in the presenter, makes their containers and returns them.
- `#serialize` fills the containers later.

The containers are filled in place, so the result returned by `#add` is complete after the run.

### Example

`UserSerializer.to_h(users)` for 2 users with posts, where each post has comments:

```
object groups        objects                      filled by
UserSerializer       [user1, user2]               group 1
PostSerializer       [post1, post2, post3]        group 2 (posts of both users)
CommentSerializer    [comment1, ..., commentN]    group 3 (comments of all posts)
```

A batch loader or preload of `PostSerializer` runs once, for all 3 posts.

### Errors

`SeregaUtils::SerializedAttributeError` adds the attribute name and the serializer class to an error raised while a value is read, preloaded or batch loaded:

```
undefined method 'bar' for an instance of User
(when serializing 'foo' attribute in UserSerializer)
```

## Per-serializer classes

Each serializer class gets subclasses of the internal classes in its `inherited` hook (`lib/serega.rb`), for example `UserSerializer::SeregaPlan` and `UserSerializer::SeregaObjectGroup`. `serializer_class` on these classes returns the serializer. Plugins include modules into these subclasses. Thus a plugin changes only the serializer that loads it, and the serializer's subclasses.

## Where plugins change the flow

| plugin | patched method | change |
|---|---|---|
| `:if` | `SeregaObjectGroup#serialize_point` | skips values that fail `:if`, `:unless`, `:if_value` or `:unless_value` |
| `:if` | `SeregaResultBuilder#build_containers` | makes `:data` containers with nil values, thus skipped attributes are nil |
| `:root` | `Serega#serialize` | wraps the result: `{root => result}` |
| `:metadata`, `:context_metadata` | `Serega#serialize` | add metadata keys next to the root key |
| `:formatters` | `SeregaAttribute` | formats the value after it is read |
| `:camel_case` | `SeregaAttributeNormalizer` | camelizes attribute names |
| `:activerecord_preloads` | `preload_with` handler | runs `ActiveRecord::Associations::Preloader` in `point.run_preloads` |
| `:depth_limit` | `SeregaPlan#initialize` | raises when the plan is too deep |
| `:string_modifiers` | `SeregaPlanCache` | parses modifiers from strings like `"name,posts(title)"` |

A patched method has a "Patched in:" line in its doc comment.

## Checks

Run `bundle exec rake` before a commit. It runs the specs and rubocop. The specs must keep 100% line and branch coverage.
