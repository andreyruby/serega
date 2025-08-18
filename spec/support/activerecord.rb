# frozen_string_literal: true

# Some old versions of ActiveRecord use Logger, but don't load it.
require "logger"
require "active_record"

pool = ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

# :nocov:
conn = (ActiveRecord.version >= Gem::Version.new("8.0.0")) ? pool.lease_connection : pool.connection
# :nocov:

conn.create_table(:users) do |t|
  t.string :first_name
  t.string :last_name
end

conn.create_table(:posts) do |t|
  t.belongs_to :user, index: false
  t.string :text
end

conn.create_table(:comments) do |t|
  t.belongs_to :post, index: false
  t.string :text
end

conn.create_table(:votes) do |t|
  t.belongs_to :comment, index: false
  t.integer :stars
end

module AR
  class User < ActiveRecord::Base
    has_many :posts
  end

  class Post < ActiveRecord::Base
    belongs_to :user
    has_many :comments
  end

  class Comment < ActiveRecord::Base
    belongs_to :post
    has_many :votes
  end

  class Vote < ActiveRecord::Base
    belongs_to :comment
  end
end

RSpec.configure do |config|
  config.around :each, :with_rollback do |example|
    ActiveRecord::Base.transaction do
      example.run
    ensure
      raise ActiveRecord::Rollback
    end
  end
end
