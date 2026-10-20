# frozen_string_literal: true

# Shared setup of the serializer benchmarks: gems, records and serializers.
# Each benchmark script requires this file and runs one case with `benchmark`.

require "bundler/inline"

gemfile(true, quiet: true) do
  source "https://rubygems.org"

  gem "serega", path: File.expand_path("..", __dir__)
  gem "active_model_serializers", "0.10.16"
  gem "alba", "4.0.1"
  gem "blueprinter", "1.3.0"
  gem "oj_serializers", "3.0.2", require: false
  gem "panko_serializer", "0.8.5"

  gem "activerecord", "8.1.4"
  gem "benchmark-ips", "2.15.1"
  gem "oj", "3.17.7"
  gem "sqlite3", "2.10.1"
end

RubyVM::YJIT.enable if defined?(RubyVM::YJIT.enable)

require "active_record"
require "benchmark/ips"
require "json"

# --- Records ---

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false

ActiveRecord::Schema.define do
  create_table :users do |t|
    t.string :name
  end

  create_table :posts do |t|
    t.string :title
    t.text :body
    t.integer :author_id
    t.datetime :created_at
  end

  create_table :comments do |t|
    t.integer :post_id
    t.text :body
    t.datetime :created_at
  end
end

class User < ActiveRecord::Base
end

class Post < ActiveRecord::Base
  belongs_to :author, class_name: "User"
  has_many :comments, -> { order(:id) }
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

time = Time.utc(2026, 1, 1, 12, 0, 0, 123_000)
users = (1..10).map { |id| {id:, name: "User #{id}"} }
posts = (1..100).map do |id|
  {id:, title: "Post #{id}", body: "Body of post #{id}", author_id: (id % 10) + 1, created_at: time + (id * 3600)}
end
comments = (1..1000).map do |id|
  {id:, post_id: ((id - 1) / 10) + 1, body: "Comment #{id}", created_at: time + (id * 60)}
end

User.insert_all!(users)
Post.insert_all!(posts)
Comment.insert_all!(comments)

# 100 posts with preloaded authors and comments, 10 comments per post.
POSTS = Post.includes(:author, :comments).order(:id).to_a
POST = POSTS.first

# --- Hand-written hashes, the fastest possible result ---

module PlainRuby
  module_function

  def post(post)
    {id: post.id, title: post.title, body: post.body, author_id: post.author_id, created_at: post.created_at.iso8601(3)}
  end

  def post_with_relations(post)
    comments = post.comments.map { |comment| comment(comment) }
    {
      id: post.id, title: post.title, body: post.body, author_id: post.author_id, created_at: post.created_at.iso8601(3),
      author: user(post.author), comments:
    }
  end

  def user(user)
    {id: user.id, name: user.name}
  end

  def comment(comment)
    {id: comment.id, body: comment.body, created_at: comment.created_at.iso8601(3)}
  end
end

# --- serega ---

require "serega"

class SeregaUserSerializer < Serega
  attribute :id
  attribute :name
end

class SeregaCommentSerializer < Serega
  attribute :id
  attribute :body
  attribute :created_at, format: [:iso8601, 3]
end

class SeregaPostSerializer < Serega
  attribute :id
  attribute :title
  attribute :body
  attribute :author_id
  attribute :created_at, format: [:iso8601, 3]
end

class SeregaPostWithRelationsSerializer < SeregaPostSerializer
  attribute :author, serializer: SeregaUserSerializer, many: false
  attribute :comments, serializer: SeregaCommentSerializer, many: true
end

# --- alba ---

require "alba"

class AlbaUserResource
  include Alba::Resource

  attributes :id, :name
end

class AlbaCommentResource
  include Alba::Resource

  attributes :id, :body, :created_at

  def created_at(comment) = comment.created_at.iso8601(3)
end

class AlbaPostResource
  include Alba::Resource

  attributes :id, :title, :body, :author_id, :created_at

  def created_at(post) = post.created_at.iso8601(3)
end

class AlbaPostWithRelationsResource < AlbaPostResource
  one :author, resource: AlbaUserResource
  many :comments, resource: AlbaCommentResource
end

# --- blueprinter ---

require "blueprinter"

# Reads fields with `public_send`, without the Hash and datetime checks of the
# default extractor. Set before the blueprints, as associations keep it.
Blueprinter.configure { |config| config.extractor_default = Blueprinter::PublicSendExtractor }

class BlueprinterIsoTimeExtractor < Blueprinter::Extractor
  def extract(field_name, object, _local_options, _options = {})
    object.public_send(field_name).iso8601(3)
  end
end

ISO_TIME_EXTRACTOR = BlueprinterIsoTimeExtractor.new

class UserBlueprint < Blueprinter::Base
  fields :id, :name
end

class CommentBlueprint < Blueprinter::Base
  fields :id, :body
  field :created_at, extractor: ISO_TIME_EXTRACTOR
end

class PostBlueprint < Blueprinter::Base
  fields :id, :title, :body, :author_id
  field :created_at, extractor: ISO_TIME_EXTRACTOR

  view :with_relations do
    association :author, blueprint: UserBlueprint
    association :comments, blueprint: CommentBlueprint
  end
end

# --- panko_serializer ---

require "panko_serializer"

class PankoUserSerializer < Panko::Serializer
  attributes :id, :name
end

class PankoCommentSerializer < Panko::Serializer
  attributes :id, :body, :created_at

  def created_at = object.created_at.iso8601(3)
end

class PankoPostSerializer < Panko::Serializer
  attributes :id, :title, :body, :author_id, :created_at

  def created_at = object.created_at.iso8601(3)
end

class PankoPostWithRelationsSerializer < PankoPostSerializer
  has_one :author, serializer: PankoUserSerializer
  has_many :comments, serializer: PankoCommentSerializer
end

# --- active_model_serializers ---

require "active_model_serializers"

ActiveModelSerializers.logger = Logger.new(nil)

class AmsUserSerializer < ActiveModel::Serializer
  attributes :id, :name
end

class AmsCommentSerializer < ActiveModel::Serializer
  attributes :id, :body, :created_at

  def created_at = object.created_at.iso8601(3)
end

class AmsPostSerializer < ActiveModel::Serializer
  attributes :id, :title, :body, :author_id, :created_at

  def created_at = object.created_at.iso8601(3)
end

class AmsPostWithRelationsSerializer < AmsPostSerializer
  belongs_to :author, serializer: AmsUserSerializer
  has_many :comments, serializer: AmsCommentSerializer
end

# --- oj_serializers ---

# oj_serializers calls `Oj.optimize_rails` on load unless `use_raw_json` is
# already set. That would switch ActiveSupport JSON encoding of the other gems
# to Oj, so the option is set here and Oj stays local to oj_serializers.
Oj.default_options = {use_raw_json: true}
require "active_support/core_ext/string/starts_ends_with" # loaded with `rails`, which oj_serializers skips now
require "oj_serializers"

class OjUserSerializer < Oj::Serializer
  attributes :id, :name
end

class OjCommentSerializer < Oj::Serializer
  attributes :id, :body
  attribute(:created_at) { @object.created_at.iso8601(3) }
end

class OjPostSerializer < Oj::Serializer
  attributes :id, :title, :body, :author_id
  attribute(:created_at) { @object.created_at.iso8601(3) }
end

class OjPostWithRelationsSerializer < OjPostSerializer
  has_one :author, serializer: OjUserSerializer
  has_many :comments, serializer: OjCommentSerializer
end

# --- Runner ---

# Checks every report returns the data of the "plain ruby" report, then
# measures them. A :json report returns a JSON String, a :hash report returns
# Hashes; their keys may be Strings or Symbols. FAST=1 runs a short round.
def benchmark(name, format, reports)
  parse = ->(result) { JSON.parse((format == :json) ? result : JSON.generate(result)) }
  expected = parse.call(reports.fetch("plain ruby").call)

  reports.each do |report, block|
    result = block.call
    raise "#{report}: returns #{result.class}, not a #{format} result" unless result.is_a?((format == :json) ? String : Enumerable)

    path = first_difference(expected, parse.call(result))
    raise "#{report}: output differs from plain ruby at #{path}" if path
  end

  puts "#{RUBY_DESCRIPTION}, #{name} #{format}: #{reports.size} outputs match plain ruby"
  Benchmark.ips do |x|
    x.config(time: 0.25, warmup: 0.1) if ENV["FAST"]
    reports.each { |report, block| x.report(report, &block) }
    x.compare!
  end
end

# Returns the path of the first value that differs, like `$[0].comments[1].body`.
def first_difference(expected, actual, path = "$")
  case expected
  when Hash
    return path unless actual.is_a?(Hash) && actual.keys.sort == expected.keys.sort
    expected.each_key.lazy.filter_map { |key| first_difference(expected[key], actual[key], "#{path}.#{key}") }.first
  when Array
    return path unless actual.is_a?(Array) && actual.size == expected.size
    expected.each_index.lazy.filter_map { |index| first_difference(expected[index], actual[index], "#{path}[#{index}]") }.first
  else
    path unless expected == actual
  end
end
