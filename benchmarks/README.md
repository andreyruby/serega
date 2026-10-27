# Benchmarks

serega against alba, blueprinter, panko_serializer, active_model_serializers,
oj_serializers and a hand-written Hash. Serializations per second, more is
better.

## Results

JSON strings:

<!-- benchmarks:json -->
| Serializer               |    1 post | 100 posts | 100 posts with relations | `only:` | `except:` |
|--------------------------|----------:|----------:|-------------------------:|--------:|----------:|
| **Serega**               | 2,261,852 |    27,196 |                    2,749 |   6,110 |     4,255 |
| oj_serializers           |   795,018 |    21,736 |                    2,207 |       — |         — |
| panko_serializer         |   593,879 |    17,403 |                    1,703 |   3,828 |     2,594 |
| alba                     |   856,323 |    14,441 |                    1,248 |       — |         — |
| blueprinter              |   653,782 |     8,827 |                      877 |       — |         — |
| active_model_serializers |    70,057 |     1,058 |                       79 |     122 |         — |
| *hand-written Hash*      | 2,350,489 |    27,118 |                    2,564 |   5,656 |     3,878 |
<!-- benchmarks:json:end -->

Hashes:

<!-- benchmarks:hash -->
| Serializer               |    1 post | 100 posts | 100 posts with relations | `only:` | `except:` |
|--------------------------|----------:|----------:|-------------------------:|--------:|----------:|
| **Serega**               | 3,485,435 |    40,994 |                    3,817 |   8,773 |     6,254 |
| oj_serializers           | 3,395,891 |    38,786 |                    3,360 |       — |         — |
| panko_serializer         |   825,353 |    13,794 |                    1,352 |   2,647 |     1,857 |
| alba                     | 1,190,736 |    16,804 |                    1,430 |       — |         — |
| blueprinter              |   753,478 |     9,997 |                      966 |       — |         — |
| active_model_serializers |    74,193 |     1,087 |                       82 |     123 |         — |
| *hand-written Hash*      | 3,817,769 |    41,005 |                    3,504 |   7,710 |     5,475 |
<!-- benchmarks:hash:end -->

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
- **JSON.** Each gem renders JSON its own way: serega with `to_json`, which
  calls `JSON.generate`, alba and blueprinter with `JSON.generate`,
  oj_serializers and panko_serializer with Oj,
  active_model_serializers with ActiveSupport. oj_serializers loads with
  `Oj.default_options = {use_raw_json: true}`, thus it keeps Oj out of the
  JSON encoding of active_model_serializers.
- **Keys.** alba and panko_serializer return String keys, the others Symbol
  keys.

## Environment

Apple M4, Ruby 4.0.7 with YJIT, alba 4.0.1, blueprinter 1.3.0,
panko_serializer 0.8.5, active_model_serializers 0.10.16, oj_serializers
3.0.2, activerecord 8.1.4. The gems come from
`gemfiles/benchmarks.gemfile`, and `cases.rb` defines how each gem
serializes each case.

## Running

```sh
BUNDLE_GEMFILE=gemfiles/benchmarks.gemfile bundle install
ruby benchmarks/relations.rb         # single, collection, relations, only, except
FAST=1 ruby benchmarks/relations.rb  # a short round
```

`rake benchmarks:full` (`full.rb`) runs every case, about 1.5 minutes, and
writes the results to the tables above and to the README. Each gem measures
for 1 second after a warmup of 0.5 seconds; `TIME=5` measures for 5 seconds:

```sh
bundle exec rake benchmarks:full
TIME=5 bundle exec rake benchmarks:full
```

`rake benchmarks:check` (`check.rb`) measures Serega, the fastest other gem and
the hand-written Hash of each case for 0.5 seconds, and prints a table of the
times. CI runs it on the latest Ruby:

```sh
bundle exec rake benchmarks:check
```
