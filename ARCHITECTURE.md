# Architecture

How Serega serializes objects.

## Serialization flow

Serialization has three stages. Each stage lives for a different time.

Terms:

| term | meaning | example |
|---|---|---|
| source | an object to serialize | a user |
| relation source | what a relation attribute returns for one source | `user.posts`: a source, a collection of sources, or nil |
| serialized object | the output of one source: a Hash, Struct or Data object | `{id: 1, name: "Ann"}` |
| relation value | the serialized value of a relation attribute | the serialized posts of a user |

```
Definition   once per serializer class   Serega, SeregaAttribute, SeregaBatchLoader
     ↓
Plan         once per set of modifiers   SeregaPlan → SeregaPlanPoint, SeregaResultBuilder per mode (made on first use)
     ↓
Run          once per serialization      SeregaEngine::Run → SeregaSourceGroup per plan (root and each relation)
```

### 1. Definition

`attribute`, `batch` and `plugin` calls on a serializer class make the definition:

- `SeregaAttribute` (`lib/serega/attribute.rb`): name, options and a value resolver from `lib/serega/attribute_value_resolvers/`. `#value(object, context, batches:)` reads the value of one object.
- `SeregaBatchLoader` (`lib/serega/batch_loader.rb`): a named block that loads values of many sources in one call.

The first plan locks the class. Later definition calls raise.

### 2. Plan

`UserSerializer.new(only:, except:, with:)` gets a `SeregaPlan` from `SeregaPlanCache`.

- `SeregaPlan` (`lib/serega/plan.rb`): the attributes to serialize, as `SeregaPlanPoint`s, in definition order. `SeregaAttribute#visible?` selects them.
- `SeregaPlanPoint` (`lib/serega/plan_point.rb`): one attribute in a plan. A relation point has a `child_plan` for the relation serializer.
- `SeregaResultBuilder` (`lib/serega/result_builder.rb`): builds the serialized objects of a plan in one mode with its generated `#call` method. A plan keeps one builder per mode. `SeregaPlanCache` keeps up to `max_cached_plans_per_serializer_count` plans with modifiers (20 by default), and their builders with them.
- `SeregaResultCode` (`lib/serega/result_code.rb`): generates the code of `SeregaResultBuilder#call` from the plan points. The method reads all values of a source, then makes its serialized object in one step: a Hash literal, `Struct.new` or `Data.new`. The method reads plain attributes with their `SeregaAttributeValues` method (see below). Other attributes call `SeregaAttribute#value`. A conditional attribute (`:if`, `:unless`, `:if_value`, `:unless_value`) gets `SeregaEngine::SKIP` when it fails a condition: a serialized Hash gets no key for it, a Struct or Data gets nil. Only conditional points get the code that checks conditions.
- `SeregaAttributeValues` (`lib/serega/attribute_values.rb`): one method per attribute read with plain Ruby code (`SeregaAttribute#value_code`): a method call, a delegation, a `:const` and a `:default`. For example `def full_name(source) = source.full_name`, `def city(source) = source.profile&.city`, `def code(source) = CONSTANTS[:code]` and `def email(source) = (value = source.email).nil? ? DEFAULTS[:email] : value`. `CONSTANTS` and `DEFAULTS` hold the values by attribute name. `SeregaAttribute` defines it when the attribute is defined, with the file and line of the attribute. The class inherits from `BasicObject`, thus attribute names do not clash with methods of `Object`. An attribute named like a `BasicObject` method (`initialize`, `__send__`, ...) gets no method and is read with `SeregaAttribute#value`.

### 3. Run

`SeregaEngine::Run` (`lib/serega/engine/run.rb`) is one serialization. It has the mode, the context, and the source groups: one root group and one group per relation. A group holds the sources of one plan. It serializes the groups in two passes.

The flow of `UserSerializer.to_h(users, only: [:id, :posts], context: {})` (`lib/serega.rb`). `to_data` and `to_struct` do the same with the `:data` and `:struct` modes:

```
UserSerializer.to_h(object, opts)
├─ split opts into modifiers (only, except, with) and serialization options (context, many)
├─ serializer = UserSerializer.new(modifiers)
│  └─ plan = plan_cache.fetch(only, with, except)         stage 2, cached plan or a new one
│
└─ serializer.to_h(object, serialization options)
   ├─ normalize_serialization_opts                        validates the options, sets opts[:context]
   ├─ prepare_objects                                     calls the prepare_initial_objects handler
   ├─ prepare_initial_serialization_opts                  sets opts[:mode] (:hash) and opts[:many]
   └─ serialize                                           patched by :root, :metadata, :context_metadata
      └─ SeregaEngine::Run.call(plan, object, many:, mode:, context:)
         ├─ root_group = root_source_group(plan, object, many)
         │  ├─ sources = []
         │  ├─ pull = SeregaUtils::Pulls.append(sources, object, many)
         │  │    appends the root source(s) to `sources`, and returns the pull (see below)
         │  └─ new_source_group(plan, sources, [pull])
         │
         ├─ source_groups = discover(root_group)                 all groups, a child group after its parent
         │  └─ for each group, also the child groups returned on the way
         │     └─ child_groups = source_group.discover
         │        ├─ run_preloads                                   once per group
         │        └─ for each relation point
         │           ├─ batches_for(point)                         once per group
         │           ├─ relation_sources = read_relation_sources(point, batches)   e.g. user.posts of each user
         │           ├─ child_sources, pulls = SeregaUtils::Pulls.collect(relation_sources, point.many)
         │           └─ child_group = run.new_source_group(point.child_plan, child_sources, pulls)
         │
         ├─ build(source_groups)                                 from the last group up
         │  └─ source_group.build
         │     ├─ batches = batches_for(point)                     once per group
         │     ├─ relations = SeregaUtils::Pulls.take!(child_group.serialized, child_group.pulls)   per relation point
         │     ├─ result_builder = plan.result_builder(mode)       kept by the plan, one per mode
         │     │  └─ first build of the plan in this mode only:
         │     │     └─ SeregaResultBuilder.new(mode, points)
         │     │        ├─ call_code = SeregaResultCode.new(mode, points).to_s   not kept
         │     │        └─ class_eval(call_code)                    defines #call on the builder
         │     └─ serialized = result_builder.call(sources, context, batches, relations)
         │
         └─ root_value(root_group)     one serialized object for SINGLE_SOURCE, or all of them
```

`SeregaSourceGroup` (`lib/serega/source_group.rb`) holds all sources of one plan in one run.

- `#initialize` wraps the sources in the presenter. The group keeps the pulls of its parent group.
- `#discover` runs the preloads and returns one child group per relation.
- `#build` builds the serialized objects. The child groups are built before it. It takes the relation values from the serialized objects of each child group with the pulls of the child group.

### Pulls

`SeregaUtils::Pulls` (`lib/serega/utils/pulls.rb`) handles the pulls. `.collect(relation_sources, many)` takes the relation source of each source of the parent group. It returns the sources of all relation sources, in order, and the pull of each relation source. `.append(sources, relation_source, many)` does this for one relation source. A pull says what `.take!` takes for it from the serialized objects:

| relation source | pull | relation value |
|---|---|---|
| one source | `SeregaUtils::Pulls::SINGLE_SOURCE` | the next serialized object |
| collection of N sources | `N` | Array of the next N serialized objects |
| `nil` | `nil` | `nil` |
| skipped by its `:if` or `:unless` condition | `SeregaEngine::SKIP` | no key, or nil |

A conditional relation uses `.collect_conditional`, which keeps `SKIP` as the pull. `Run#call` uses `.append` for the root. The serialized objects of a group follow the order of its sources, thus `.take!(serialized, pulls)` takes them from the front, one pull after another, and empties them: the parent group takes them once, during its build. The root group has one pull: `Run#call` returns its one serialized object for `SINGLE_SOURCE`, or all its serialized objects.

The keys of a serialized object follow the order of the plan points. The values are read source by source. Relation values and preloads of a group are read in the discover pass, before the other values.

### Example

`UserSerializer.to_h([ann, bob, cat])`, where a user has posts and an avatar, and a post has comments:

| user | posts | avatar |
|---|---|---|
| ann | `[p1, p2]` (p1 has comments c1, c2; p2 has none) | `a1` |
| bob | `nil` | `nil` |
| cat | `[p3]` (p3 has comment c3) | `a3` |

Discover pass, from the root group down. Each group makes one child group per relation:

```
users group: [ann, bob, cat]                    pulls: [3]                   one collection of 3 users
│
├─ posts relation → posts group
│    sources: [p1, p2, p3]                      posts of all users, in user order
│    pulls:   [2, nil, 1]                       one per user: ann 2 posts, bob nil, cat 1 post
│    │
│    └─ comments relation → comments group
│         sources: [c1, c2, c3]                 comments of all posts, in post order
│         pulls:   [2, 0, 1]                    one per post: p1 2 comments, p2 none, p3 1 comment
│
└─ avatar relation → avatars group
     sources: [a1, a3]
     pulls:   [SINGLE_SOURCE, nil, SINGLE_SOURCE]
```

`Run#discover` returns the groups in discover order: `[users, posts, avatars, comments]`. A batch loader or preload of the posts group runs once, for all 3 posts.

Build pass, from the last group up. `S(x)` is the serialized object of `x`:

```
comments group   serialized:      [S(c1), S(c2), S(c3)]
                 relation_values: [[S(c1), S(c2)], [], [S(c3)]]          comments of p1, p2, p3

avatars group    serialized:      [S(a1), S(a3)]
                 relation_values: [S(a1), nil, S(a3)]                    avatar of ann, bob, cat

posts group      serialized:      [S(p1), S(p2), S(p3)]                  with the comments values
                 relation_values: [[S(p1), S(p2)], nil, [S(p3)]]         posts of ann, bob, cat

users group      serialized:      [S(ann), S(bob), S(cat)]               with the posts and avatar values
                 pulls: [3], thus Run.call returns [S(ann), S(bob), S(cat)]
```

### When the `#call` method is generated

The build pass generates the `#call` method of a plan the first time it builds a group of this plan in a serialization mode:

1. `plan.result_builder(mode)` finds no builder of this mode in the plan.
2. `SeregaResultBuilder.new(mode, points)` gets the code from `SeregaResultCode.new(mode, points).to_s`, and defines `#call` with `class_eval`. This takes about 60 µs for 10 attributes.
3. Nothing keeps the `SeregaResultCode` object or the code string. The plan keeps the builder with the generated `#call`. Later builds of the plan in this mode call the same method.

A child plan belongs to its parent plan, thus it keeps its builders as long as the parent plan lives. How long a plan lives:

| plan | lives | `#call` is generated |
|---|---|---|
| without modifiers | as long as the serializer class | once per mode |
| with modifiers, cached (`max_cached_plans_per_serializer_count`, 20 by default) | until the cache removes it | once per mode while cached |
| with modifiers, cache disabled (`0`) | one serialization | in each serialization |

### Build order

The build pass builds the groups in reverse order: the serialized related objects must be ready before the serialized objects that hold them.

- `Run#discover` puts a child group after the group that reads its relation sources. Thus a child group always comes after its parent group: `[users, posts, avatars, comments]`.
- A serialized object holds the serialized related objects: a serialized user holds serialized posts, a serialized post holds serialized comments.
- `reverse_each` builds `comments`, then `avatars`, then `posts`, then `users`. When a group builds, the groups of its relations are already built.

A group depends only on groups added after it. A recursive serializer, for example user → friends → users, adds new groups further down the list. Thus the reverse order is always valid.

A build from the root down must assign the relation values after it makes the serialized parent objects. A `Data` object is frozen when it is made, thus it can not get values later.

### Errors

`SeregaUtils::SerializedAttributeError` adds the attribute name, the serializer class and the line where the attribute is defined to an error raised while a value is read, preloaded or batch loaded:

```
undefined method 'bar' for an instance of User
(when serializing the 'foo' attribute in UserSerializer, app/serializers/user_serializer.rb:3)
```

An error raised by an `:if`, `:unless`, `:if_value` or `:unless_value` condition names the condition:

```
undefined method 'active?' for an instance of User
(when checking the :if condition of the 'email' attribute in UserSerializer, app/serializers/user_serializer.rb:4)
```

Each value read in the generated `#call` has its own `rescue`. Conditions are checked outside it, thus an error gets one of these lines.

`Serega.attribute` records the location: the first caller outside Serega's own files. A subclass keeps the location of the parent attribute.

A plain attribute is read by its `SeregaAttributeValues` method, defined with the file and line of the attribute. Thus the backtrace points to the attribute too. The generated `#call` has a virtual file name:

```
app/serializers/user_serializer.rb:3:in 'UserSerializer::SeregaAttributeValues#full_name'
(serega generated code):20:in 'call'
lib/serega/source_group.rb:134:in 'Serega::SeregaSourceGroup::InstanceMethods#build'
```

## Per-serializer classes

Each serializer class gets subclasses of the internal classes in its `inherited` hook (`lib/serega.rb`), for example `UserSerializer::SeregaPlan` and `UserSerializer::SeregaSourceGroup`. `serializer_class` on these classes returns the serializer. Plugins include modules into these subclasses. Thus a plugin changes only the serializer that loads it, and the serializer's subclasses.

## Where plugins change the flow

| plugin | patched method | change |
|---|---|---|
| `:root` | `Serega#serialize` | wraps the serialized object(s): `{root => serialized}` |
| `:metadata`, `:context_metadata` | `Serega#serialize` | add metadata keys next to the root key |
| `:formatters` | `SeregaAttribute#value`, `#value_code` | formats the value after it is read; a formatted attribute is not read directly in generated code |
| `:camel_case` | `SeregaAttributeNormalizer` | camelizes attribute names |
| `:activerecord_preloads` | `preload_with` handler | runs `ActiveRecord::Associations::Preloader` in `SeregaSourceGroup#run_preloads` |
| `:depth_limit` | `SeregaPlan#initialize` | raises when the plan is too deep |
| `:string_modifiers` | `SeregaPlanCache` | parses modifiers from strings like `"name,posts(title)"` |

A patched method has a "Patched in:" line in its doc comment.

## Checks

Run `bundle exec rake` before a commit. It runs the specs and rubocop. The specs must keep 100% line and branch coverage.
