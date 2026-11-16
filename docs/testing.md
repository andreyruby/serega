# Testing Serializers

Serega has no testing DSL and no test helpers. A serializer is a Ruby class,
and its specs call `to_h` like the app does and compare the result.

This guide is an example for inspiration: the way the gem author tests
serializers, not a rule. Keep what fits your app. The examples use RSpec and
FactoryBot, and the ideas work with any test tools.

The examples test this serializer:

```ruby
class UserSerializer < Serega
  config.hide_by_default = :auto

  attribute :first_name
  attribute :email, if: proc { |user, ctx| user == ctx[:current_user] }
  attribute :link, value: UserLink
  attribute :followers_count, batch: FollowersCount, default: 0
end
```

## Table of Contents

<!-- toc -->

- [Testing one attribute at a time](#testing-one-attribute-at-a-time)
- [Testing the fields serialized by default](#testing-the-fields-serialized-by-default)
- [Testing attributes that read the context](#testing-attributes-that-read-the-context)
- [Moving complex values to their own classes](#moving-complex-values-to-their-own-classes)
- [Testing batch loaders](#testing-batch-loaders)
- [Counting queries with ActiveRecord](#counting-queries-with-activerecord)

<!-- tocstop -->

## Testing one attribute at a time

`selection` holds the [field selection](selecting-fields.md) options.
`{only: :first_name}` serializes one attribute, so each example builds only the
data that attribute needs:

```ruby
RSpec.describe UserSerializer do
  subject(:result) { described_class.to_h(user, **selection, context: context) }

  let(:user) { build_stubbed(:user, first_name: "Felonious", username: "gru", email: "gru@example.com") }
  let(:context) { {} }

  context "#first_name" do
    let(:selection) { {only: :first_name} }

    it "serializes the first name" do
      expect(result).to eq(first_name: "Felonious")
    end
  end
end
```

The user comes from `build_stubbed` and is never saved: a serializer only reads
the objects it gets, and such specs run fast. `build`, `User.new` or a `Struct`
works the same way.

## Testing the fields serialized by default

An empty `selection` serializes the fields a response has by default. With
`hide_by_default = :auto`, it catches a batch or a relation that starts to load
for every response:

```ruby
describe "default fields" do
  let(:selection) { {} }

  it "skips the batch-loaded fields" do
    expect(result.keys).to eq(%i[first_name link])
  end
end
```

## Testing attributes that read the context

A context per value of the [context](context.md) shows each outcome:

```ruby
context "#email" do
  let(:selection) { {only: :email} }

  context "when the user is the current user" do
    let(:context) { {current_user: user} }

    it "serializes the email" do
      expect(result).to eq(email: "gru@example.com")
    end
  end

  context "when the user is another user" do
    let(:context) { {current_user: build_stubbed(:user)} }

    it "skips the email" do
      expect(result).to eq({})
    end
  end
end
```

## Moving complex values to their own classes

When a `value:` or `batch:` proc grows past a line or two, it can move to its
own class with its own spec. `:value` and `:batch` accept any object that
responds to `#call`:

```ruby
class UserLink
  def self.call(user)
    return unless user.username

    "https://example.com/@#{user.username}"
  end
end
```

The class spec covers the edge cases:

```ruby
RSpec.describe UserLink do
  subject(:link) { described_class.call(user) }

  let(:user) { build_stubbed(:user, username: username) }

  context "when the user has a username" do
    let(:username) { "gru" }

    it "links to the user page" do
      expect(link).to eq("https://example.com/@gru")
    end
  end

  context "when the user has no username" do
    let(:username) { nil }

    it "returns nil" do
      expect(link).to be_nil
    end
  end
end
```

The serializer spec then needs one example that the attribute uses the class:

```ruby
context "#link" do
  let(:selection) { {only: :link} }

  it "serializes the user link" do
    expect(result).to eq(link: "https://example.com/@gru")
  end
end
```

## Testing batch loaders

A loader class runs a query, so its spec saves records. A record of a user
that is not passed to the loader shows that the loader reads only the given
users:

```ruby
class FollowersCount
  def self.call(users)
    Follow.where(user: users).group(:user_id).count
  end
end

RSpec.describe FollowersCount do
  subject(:counts) { described_class.call(users) }

  let(:gru) { create(:user) }
  let(:lucy) { create(:user) }
  let(:margo) { create(:user) }
  let(:users) { [gru, lucy] }

  before do
    create(:follow, user: gru, follower: lucy)
    create(:follow, user: gru, follower: margo)
    create(:follow, user: margo, follower: gru)
  end

  context "when some users have followers" do
    it "counts the followers of each user" do
      expect(counts).to eq(gru.id => 2)
    end
  end
end
```

## Counting queries with ActiveRecord

A spec can count the SQL queries of a serialization, to see that
[preloads](preloads.md) and [batch loaders](batch-loading.md) keep one query
per relation. A helper in `spec/support` can count them for every spec. It
skips the schema queries ActiveRecord runs when it first loads a model:

```ruby
# spec/support/count_queries.rb
module CountQueries
  def count_queries(&block)
    count = 0
    callback = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
    count
  end
end

RSpec.configure do |config|
  config.include CountQueries
end
```

The spec saves records, so the queries run against real data:

```ruby
context "with several users" do
  let!(:users) { create_list(:user, 2) }
  let(:selection) { {only: %i[first_name followers_count]} }

  it "runs one query for the followers of all users" do
    queries = count_queries { described_class.to_h(users, **selection) }

    expect(queries).to eq(1)
  end
end
```
