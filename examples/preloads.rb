# frozen_string_literal: true

require "bundler/inline"

gemfile(true, quiet: true) do
  source "https://rubygems.org"
  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "serega", path: File.join(File.dirname(__FILE__), "..")
  gem "sqlite3"
  gem "activerecord"
end

class AppSerializer < Serega
end

require "active_record"
require "logger"

logger = Logger.new($stdout)
logger.level = Logger::INFO
logger.formatter = proc { |severity, datetime, progname, msg| msg << "\n" }
ActiveRecord::Base.logger = logger
ActiveSupport::LogSubscriber.colorize_logging = false
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

# Schema (user has many posts, post has many comments)
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :first_name
    t.string :last_name
  end

  create_table :posts, force: true do |t|
    t.integer :user_id
    t.string :text
  end

  create_table :comments, force: true do |t|
    t.integer :post_id
    t.integer :user_id
    t.string :text
  end
end

# Models
class User < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :user, optional: true
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post, optional: true
  belongs_to :user, optional: true
end

# Data
user1 = User.create!(first_name: "Bruce", last_name: "Wayne")
user2 = User.create!(first_name: "Clark", last_name: "Kent")
user3 = User.create!(first_name: "Jane", last_name: "Doe")

post1 = Post.create!(user: user1, text: "post1")
post2 = Post.create!(user: user1, text: "post2")

Comment.create!(user: user1, post: post1, text: "comment1")
Comment.create!(user: user2, post: post1, text: "comment2")
Comment.create!(user: user3, post: post2, text: "comment3")
Comment.create!(user: user1, post: post2, text: "comment4")

# Serializers
class AppSerializer < Serega
  plugin :activerecord_preloads

  config.auto_preload = true
  config.hide_by_default = false
end

class UserSerializer < AppSerializer
  attribute :first_name
  attribute :last_name
  attribute :posts, serializer: -> { PostSerializer }
end

class PostSerializer < AppSerializer
  attribute :text
  attribute :comments, serializer: -> { CommentSerializer }
end

class CommentSerializer < AppSerializer
  attribute :text
  # attribute :user, serializer: -> { UserSerializer }
end

def example(message, expected_queries_count:)
  sqls = Storage.sqls
  sqls.clear

  yield

  if sqls.count != expected_queries_count
    raise "#{message}: expected #{expected_queries_count}, but there were #{sqls.count} requests: \n - #{sqls.join("\n - ")}"
  end
end

class Storage
  @sqls = []

  class << self
    attr_accessor :sqls
  end
end

ActiveSupport::Notifications.subscribe "sql.active_record" do |_name, _started, _finished, _id, payload|
  Storage.sqls << payload[:sql]
end

user1.reload
example("Single object", expected_queries_count: 2) do # loads posts, comments
  UserSerializer.new.call(user1)
end

user1.reload
user1.posts.create!(text: "post3")
example("Single object with created post", expected_queries_count: 2) do # loads posts, comments
  UserSerializer.new.to_h(user1)
end

users = [user1.reload, user2.reload, user3.reload]
example("Array", expected_queries_count: 2) do # loads posts, comments
  UserSerializer.new.to_h(users)
end

users = [user1.reload, user2.reload, user3.reload]
user1.posts.create!(text: "post4")
example("Array with created posts in some user", expected_queries_count: 2) do # loads posts, comments
  UserSerializer.new.to_h(users)
end

users = User.all
example("Relation", expected_queries_count: 3) do # loads users, posts, comments
  UserSerializer.new.to_h(users)
end

users = User.all.load
example("Loaded Relation", expected_queries_count: 2) do # loads posts, comments
  UserSerializer.new.to_h(users)
end

users = User.all.includes(:posts)
example("Relation included posts", expected_queries_count: 3) do # loads users, posts, comments
  UserSerializer.new.to_h(users)
end

users = User.all.includes(:posts).load
example("Loaded attribute included posts", expected_queries_count: 1) do # loads only comments
  UserSerializer.new.to_h(users)
end

comments = Comment.all
example("No preloads", expected_queries_count: 1) do # loads only comments
  CommentSerializer.to_h(comments)
end
