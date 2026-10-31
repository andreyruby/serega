# Benchmarks

serega against alba, blueprinter, panko_serializer, active_model_serializers,
oj_serializers and a hand-written Hash. Serializations per second, more is
better.

## Results

JSON strings:

<!-- benchmarks:json -->
| Serializer               |    1 post | 100 posts | 100 posts with relations | `only:` | `except:` |
|--------------------------|----------:|----------:|-------------------------:|--------:|----------:|
| **Serega**               | 1,164,656 |    14,066 |                    1,427 |   2,924 |     1,955 |
| oj_serializers           |   387,440 |    11,530 |                    1,058 |       — |         — |
| panko_serializer         |   406,907 |    14,384 |                    1,185 |   2,787 |     1,922 |
| alba                     |   337,815 |     5,054 |                      475 |       — |         — |
| blueprinter              |   273,517 |     3,368 |                      360 |       — |         — |
| active_model_serializers |    37,767 |       668 |                       52 |      78 |         — |
| *hand-written Hash*      | 1,257,325 |    14,337 |                    1,327 |   2,813 |     1,935 |
<!-- benchmarks:json:end -->

Hashes:

<!-- benchmarks:hash -->
| Serializer               |    1 post | 100 posts | 100 posts with relations | `only:` | `except:` |
|--------------------------|----------:|----------:|-------------------------:|--------:|----------:|
| **Serega**               | 1,543,685 |    17,037 |                    1,657 |   3,385 |     2,328 |
| oj_serializers           | 1,445,839 |    16,313 |                    1,377 |       — |         — |
| panko_serializer         |   502,677 |     9,269 |                      856 |   1,731 |     1,179 |
| alba                     |   421,311 |     5,346 |                      503 |       — |         — |
| blueprinter              |   302,706 |     3,625 |                      377 |       — |         — |
| active_model_serializers |    40,633 |       677 |                       53 |      79 |         — |
| *hand-written Hash*      | 1,699,859 |    17,119 |                    1,535 |   3,266 |     2,221 |
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

Apple M4, Ruby 4.0.7 without a JIT, alba 4.0.1, blueprinter 1.3.0,
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

The scripts and the rake tasks run without a JIT. `RUBY_YJIT_ENABLE=1` runs
them with YJIT:

```sh
RUBY_YJIT_ENABLE=1 ruby benchmarks/relations.rb
RUBY_YJIT_ENABLE=1 bundle exec rake benchmarks:check
```

`rake benchmarks:full` (`full.rb`) runs every case, about 1.5 minutes, and
writes the results to the tables above. Each gem measures for 1 second after
a warmup of 0.5 seconds; `TIME=5` measures for 5 seconds:

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
