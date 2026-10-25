# Benchmarks

serega against alba, blueprinter, panko_serializer, active_model_serializers,
oj_serializers and a hand-written Hash. Serializations per second, more is
better.

## Results

JSON strings:

<!-- benchmarks:json -->
| Serializer               |    1 post | 100 posts | 100 posts with relations | `only:` | `except:` |
|--------------------------|----------:|----------:|-------------------------:|--------:|----------:|
| **Serega**               | 2,379,261 |    27,634 |                    2,752 |   6,380 |     4,342 |
| oj_serializers           |   787,237 |    21,976 |                    2,281 |       — |         — |
| panko_serializer         |   551,857 |    17,715 |                    1,715 |   3,938 |     2,634 |
| alba                     |   848,911 |    14,043 |                    1,249 |       — |         — |
| blueprinter              |   657,010 |     9,216 |                      914 |       — |         — |
| active_model_serializers |    70,687 |     1,052 |                       81 |     122 |         — |
| *hand-written Hash*      | 2,450,662 |    28,238 |                    2,639 |   5,922 |     4,000 |
<!-- benchmarks:json:end -->

Hashes:

<!-- benchmarks:hash -->
| Serializer               |    1 post | 100 posts | 100 posts with relations | `only:` | `except:` |
|--------------------------|----------:|----------:|-------------------------:|--------:|----------:|
| **Serega**               | 3,849,814 |    42,576 |                    3,879 |   8,937 |     6,341 |
| oj_serializers           | 3,592,834 |    40,529 |                    3,372 |       — |         — |
| panko_serializer         |   815,518 |    13,810 |                    1,346 |   2,664 |     1,823 |
| alba                     | 1,205,664 |    17,316 |                    1,453 |       — |         — |
| blueprinter              |   784,825 |    10,351 |                    1,012 |       — |         — |
| active_model_serializers |    74,610 |     1,057 |                       80 |     123 |         — |
| *hand-written Hash*      | 3,978,056 |    42,410 |                    3,561 |   7,703 |     5,657 |
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

Apple M4, Ruby 4.0.5 with YJIT, alba 4.0.1, blueprinter 1.3.0,
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
writes the results to the tables above and to the README. Then `chart.rb`
draws `assets/benchmarks.svg` from the JSON table of the README;
`ruby benchmarks/chart.rb` redraws it alone. Each gem measures for 1 second
after a warmup of 0.5 seconds; `TIME=5` measures for 5 seconds:

```sh
bundle exec rake benchmarks:full
TIME=5 bundle exec rake benchmarks:full
```

`rake benchmarks:check` (`check.rb`) fails when Serega is more than 2% slower
than the fastest other gem of a case, or slower than the hand-written Hash:
more than 10% slower in the single and collection cases, slower at all in the
relations, `only:` and `except:` cases. It measures each case for 0.5
seconds, and a case that fails for 1.5 seconds more, and prints a table of the
times. CI runs it on the latest Ruby:

```sh
bundle exec rake benchmarks:check
```
