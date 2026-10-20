# Benchmarks

serega against alba, blueprinter, panko_serializer, active_model_serializers,
oj_serializers and a hand-written Hash. Serializations per second, more is
better.

## Results

JSON strings:

| Serializer               |    1 post | 100 posts | 100 posts with relations | `only:` | `except:` |
|--------------------------|----------:|----------:|-------------------------:|--------:|----------:|
| **serega**               |   893,663 |    24,550 |                    2,394 |   4,812 |     3,648 |
| oj_serializers           |   760,696 |    21,209 |                    2,145 |       — |         — |
| panko_serializer         |   544,390 |    16,953 |                    1,629 |   3,915 |     2,563 |
| alba                     |   775,201 |    14,133 |                    1,281 |       — |         — |
| blueprinter              |   610,544 |     8,875 |                      893 |       — |         — |
| active_model_serializers |    68,363 |     1,022 |                       79 |     118 |         — |
| *hand-written Hash*      | 2,271,217 |    25,775 |                    2,342 |   4,856 |     3,506 |

Hashes:

| Serializer               |    1 post | 100 posts | 100 posts with relations | `only:` | `except:` |
|--------------------------|----------:|----------:|-------------------------:|--------:|----------:|
| **serega**               | 1,086,564 |    34,839 |                    3,217 |   6,589 |     4,961 |
| oj_serializers           | 3,431,306 |    36,480 |                    2,957 |       — |         — |
| panko_serializer         |   783,211 |    13,096 |                    1,266 |   2,430 |     1,709 |
| alba                     | 1,035,371 |    16,143 |                    1,442 |       — |         — |
| blueprinter              |   709,166 |    10,062 |                      987 |       — |         — |
| active_model_serializers |    70,542 |     1,043 |                       80 |     119 |         — |
| *hand-written Hash*      | 3,812,230 |    37,498 |                    3,096 |   6,222 |     4,747 |

"—" means the gem has no runtime field selection.

## Cases

Records are preloaded ActiveRecord models in an in-memory SQLite database.

| Script          | Serializes                                                   |
|-----------------|--------------------------------------------------------------|
| `single.rb`     | 1 post: five attributes, one of them a time                  |
| `collection.rb` | 100 posts                                                    |
| `relations.rb`  | 100 posts with their author and 10 comments each             |
| `only.rb`       | 100 posts with relations, only the post id and title, the author name and the comment bodies |
| `except.rb`     | 100 posts with relations, without the post body and the comment times |

Each script runs a JSON round and a Hash round. Before it measures, it checks
that every gem returns the same data as the hand-written Hash, and names the
first value that differs.

## How each gem is called

- **Fastest definition options.** serega: `format: [:iso8601, 3]` and `many:`
  on relations. alba: resource methods instead of attribute blocks.
  blueprinter: `PublicSendExtractor` as the default extractor and an
  extractor for times. panko_serializer, active_model_serializers and
  oj_serializers: serializer methods for times. Every gem formats times with an
  explicit `iso8601(3)` call.
- **Prepared serializers.** serega serializers and panko_serializer array
  serializers serialize many times, thus they are prepared once with `.new`,
  with their field selection, and reused by every call. alba and
  active_model_serializers take the object in `.new`, panko_serializer
  instances for one object are single-use, and blueprinter and oj_serializers
  serialize with class methods.
- **One object or a collection.** Each gem is told which one it gets where its
  API allows: serega with `many:`, panko_serializer and oj_serializers with
  separate methods, active_model_serializers with
  `serializer: ActiveModel::Serializer::CollectionSerializer`. alba and
  blueprinter have no such option and check the object's class.
- **JSON.** Each gem renders JSON its own way: serega, alba and blueprinter
  with `JSON.generate`, oj_serializers and panko_serializer with Oj,
  active_model_serializers with ActiveSupport. oj_serializers loads with
  `Oj.default_options = {use_raw_json: true}`, thus it keeps Oj out of the
  JSON encoding of active_model_serializers.
- **Keys.** alba and panko_serializer return String keys, the others Symbol
  keys.

## Environment

Apple M4, Ruby 4.0.5 with YJIT, alba 4.0.1, blueprinter 1.3.0,
panko_serializer 0.8.5, active_model_serializers 0.10.16, oj_serializers
3.0.2, activerecord 8.1.4. `support.rb` installs the gems with an inline
Gemfile.

## Running

```sh
ruby benchmarks/relations.rb         # single, collection, relations, only, except
FAST=1 ruby benchmarks/relations.rb  # a short round
```
