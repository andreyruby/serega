# Benchmarks

serega against alba, blueprinter, panko_serializer, active_model_serializers,
oj_serializers and a hand-written Hash. Serializations per second, more is
better.

## Results

JSON strings:

<!-- benchmarks:json -->
| Serializer               |    1 post | 100 posts | 100 posts with relations | `only:` | `except:` |
|--------------------------|----------:|----------:|-------------------------:|--------:|----------:|
| **serega**               | 2,024,026 |    26,330 |                    2,612 |   5,151 |     3,775 |
| oj_serializers           |   730,279 |    21,000 |                    2,147 |       — |         — |
| panko_serializer         |   536,656 |    16,796 |                    1,635 |   3,872 |     2,649 |
| alba                     |   762,701 |    13,701 |                    1,292 |       — |         — |
| blueprinter              |   598,444 |     8,774 |                      903 |       — |         — |
| active_model_serializers |    66,869 |     1,035 |                       79 |     117 |         — |
| *hand-written Hash*      | 2,174,936 |    25,561 |                    2,421 |   4,822 |     3,416 |
<!-- benchmarks:json:end -->

Hashes:

<!-- benchmarks:hash -->
| Serializer               |    1 post | 100 posts | 100 posts with relations | `only:` | `except:` |
|--------------------------|----------:|----------:|-------------------------:|--------:|----------:|
| **serega**               | 3,284,688 |    37,763 |                    3,444 |   6,800 |     5,208 |
| oj_serializers           | 3,270,214 |    36,039 |                    3,082 |       — |         — |
| panko_serializer         |   780,050 |    13,424 |                    1,315 |   2,301 |     1,734 |
| alba                     | 1,029,599 |    16,290 |                    1,460 |       — |         — |
| blueprinter              |   695,835 |     9,945 |                    1,012 |       — |         — |
| active_model_serializers |    68,096 |     1,049 |                       81 |     119 |         — |
| *hand-written Hash*      | 3,681,565 |    37,399 |                    3,168 |   6,197 |     4,716 |
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

`rake benchmarks:check` (`check.rb`) fails when Serega is more than 2% slower
than the fastest other gem of a case, or slower than the hand-written Hash:
more than 10% slower in the single and collection cases, slower at all in the
relations, `only:` and `except:` cases. It measures each case for 0.5
seconds, and a case that fails for 1.5 seconds more, and prints a table of the
times. CI runs it on the latest Ruby:

```sh
bundle exec rake benchmarks:check
```
