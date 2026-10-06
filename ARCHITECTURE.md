# Architecture

How Serega serializes objects.

## Serialization flow

Serialization has three stages. Each stage lives for a different time.

Terms: an *object to serialize* is an input object, for example a user. A *serialized object* is its output: a Hash, Struct or Data object.

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
- `SeregaPlanPoint` (`lib/serega/plan_point.rb`): one attribute in a plan. A relation point has a `child_plan` for the relation serializer.
- `SeregaResultBuilder` (`lib/serega/result_builder.rb`): builds the serialized objects of a plan in one mode. It makes empty containers (`{}` for `:hash` and `:data`, a `Struct` for `:struct`), and builds the serialized objects from the filled containers: a `Data` object from each Hash in the `:data` mode, or the containers themselves.

### 3. Run

`to_h`, `to_data` and `to_struct` (`lib/serega.rb`) do these steps:

1. `normalize_serialization_opts` validates the options and sets `opts[:context]`.
2. `prepare_objects` calls the `prepare_initial_objects` handler.
3. `prepare_initial_serialization_opts` sets `opts[:mode]` and `opts[:many]`.
4. `serialize` calls `SeregaEngine::Run.call(plan, object, many:, mode:, context:)`.

`SeregaEngine::Run` (`lib/serega/engine/run.rb`) is one serialization. It has the mode, the context, and one `SeregaObjectGroup` per plan. It serializes the groups in two passes:

```
Run.call(plan, object, many:, mode:, context:)
├─ reference = run.object_group(plan).add(object, many)
│
├─ discover pass, from the root group down (also groups added during this pass)
│  └─ object_group.discover
│     ├─ run_preloads                                      once per group
│     └─ for each relation point
│        ├─ batches_for(point)                            once per group
│        ├─ child_group = run.object_group(point.child_plan)
│        └─ for each object
│           └─ reference = child_group.add(attribute.value(object, ...), point.many)
│
├─ build pass, from the last group up
│  └─ object_group.build
│     ├─ containers = result_builder.build_containers(size)
│     ├─ for each point
│     │  ├─ relation: containers[index][name] = child_group.serialized_for(reference)   already built
│     │  └─ other: batches_for(point)                                                 once per group
│     │            serialize_point: containers[index][name] = attribute.value(object, ...)
│     └─ serialized = result_builder.build(containers)
│
└─ root_group.serialized_for(reference)
```

`SeregaObjectGroup` (`lib/serega/object_group.rb`) holds all objects of one plan in one run.

- `#add` wraps the objects in the presenter and returns a reference to their serialized objects: an index for one object, a Range for a collection, nil for nil.
- `#discover` runs the preloads and adds the related objects to the groups of the relation plans.
- `#build` builds the serialized objects. The groups of the relation plans are built before it.
- `#serialized_for(reference)` returns the serialized object(s) of a reference from `#add`.

The keys of a serialized object follow the order of the plan points. The values are read point by point, for all objects of a group. Relation values and preloads of a group are read in the discover pass, before the other values.

### Example

`UserSerializer.to_h(users)` for 2 users with posts, where each post has comments:

```
object groups        objects                      discovered   built
UserSerializer       [user1, user2]               1st          3rd
PostSerializer       [post1, post2, post3]        2nd          2nd   (posts of both users)
CommentSerializer    [comment1, ..., commentN]    3rd          1st   (comments of all posts)
```

A batch loader or preload of `PostSerializer` runs once, for all 3 posts.

### Build order

The build pass builds the groups in reverse order: the serialized related objects must be ready before the serialized objects that hold them.

- The discover pass adds the group of related objects after the group that finds them. Thus a child group always comes after its parent group: `[users, posts, comments]`.
- A serialized object holds the serialized related objects: a serialized user holds serialized posts, a serialized post holds serialized comments.
- `reverse_each` builds `comments`, then `posts`, then `users`. When a group builds, the groups of its relations are already built.

A group depends only on groups added after it. A recursive serializer, for example user → friends → users, adds new groups further down the list. Thus the reverse order is always valid.

A build from the root down must assign the relation values after it makes the serialized parent objects. A `Data` object is frozen when it is made, thus it can not get values later.

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
| `:if` | `SeregaObjectGroup#serialize_point` | skips values failing `:if`, `:unless`, `:if_value` or `:unless_value` |
| `:if` | `SeregaObjectGroup#read_relations` | returns `If::SKIP` for relations of objects failing `:if` or `:unless` |
| `:if` | `SeregaObjectGroup#assign_relation_values` | skips `If::SKIP` relation values |
| `:if` | `SeregaResultBuilder#build_containers` | makes `:data` containers with nil values, thus skipped attributes are nil |
| `:root` | `Serega#serialize` | wraps the serialized object(s): `{root => serialized}` |
| `:metadata`, `:context_metadata` | `Serega#serialize` | add metadata keys next to the root key |
| `:formatters` | `SeregaAttribute` | formats the value after it is read |
| `:camel_case` | `SeregaAttributeNormalizer` | camelizes attribute names |
| `:activerecord_preloads` | `preload_with` handler | runs `ActiveRecord::Associations::Preloader` in `SeregaObjectGroup#run_preloads` |
| `:depth_limit` | `SeregaPlan#initialize` | raises when the plan is too deep |
| `:string_modifiers` | `SeregaPlanCache` | parses modifiers from strings like `"name,posts(title)"` |

A patched method has a "Patched in:" line in its doc comment.

## Checks

Run `bundle exec rake` before a commit. It runs the specs and rubocop. The specs must keep 100% line and branch coverage.
