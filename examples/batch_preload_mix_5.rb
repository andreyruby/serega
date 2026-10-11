# frozen_string_literal: true

require "bundler/inline"

gemfile(true, quiet: true) do
  source "https://rubygems.org"
  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "serega", path: File.join(File.dirname(__FILE__), "..")
  gem "sqlite3"
  gem "activerecord"
end

require "active_record"
require "logger"

logger = Logger.new($stdout)
logger.level = Logger::INFO
logger.formatter = proc { |severity, datetime, progname, msg| msg << "\n" }
ActiveRecord::Base.logger = logger
ActiveSupport::LogSubscriber.colorize_logging = false
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

# Schema
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

  create_table :views, force: true do |t|
    t.integer :comment_id
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
  has_many :views
end

class View < ActiveRecord::Base
  belongs_to :comment, optional: true
end

# Data
user1 = User.create!(first_name: "Bruce", last_name: "Wayne")
user2 = User.create!(first_name: "Clark", last_name: "Kent")
user3 = User.create!(first_name: "Jane", last_name: "Doe")

post1 = Post.create!(user: user1, text: "post1")
post2 = Post.create!(user: user1, text: "post2")

comment1 = Comment.create!(user: user1, post: post1, text: "comment1")
comment2 = Comment.create!(user: user2, post: post1, text: "comment2")
comment3 = Comment.create!(user: user3, post: post2, text: "comment3")
comment4 = Comment.create!(user: user1, post: post2, text: "comment4")

View.create!(comment: comment1)
View.create!(comment: comment2)
View.create!(comment: comment3)
View.create!(comment: comment4)
View.create!(comment: comment4)

# Loaders
class UsersPostsLoader
  def self.call(users)
    Post.where(user: users).group_by(&:user_id)
  end
end

class CommentsViewsLoader
  def self.call(comments)
    View.where(comment: comments).group(:comment_id).count
  end
end

# Serializers - Mix 5: batch posts -> preload comments -> preload views
class AppSerializer < Serega
  plugin :activerecord_preloads
end

class UserSerializer < AppSerializer
  attribute :first_name
  attribute :last_name
  attribute :posts, serializer: "PostSerializer", batch: UsersPostsLoader, default: []
end

class PostSerializer < AppSerializer
  attribute :text
  attribute :comments, serializer: "CommentSerializer", preload: :comments
end

class CommentSerializer < AppSerializer
  batch :comments_views, CommentsViewsLoader

  attribute :text
  attribute :views_count, batch: :comments_views,
    value: proc { |comment, batches:| batches[:comments_views][comment.id] }
end

puts "=== Mix 5: batch posts -> preload comments -> batch views ==="

require_relative "helpers/expected_queries_count"

expected_queries_count(3) do
  puts JSON.pretty_generate(UserSerializer.new.to_h([user1, user2, user3]))
end
