# frozen_string_literal: true

require "support/activerecord"
require "support/matchers/run_queries"

load_plugin_code :activerecord_preloads

RSpec.describe Serega::SeregaPlugins::ActiverecordPreloads do
  describe "loading" do
    let(:serializer) { Class.new(Serega) }

    it "loads successfully" do
      expect { serializer.plugin(:activerecord_preloads) }.not_to raise_error
    end

    it "raises error when any option was provided" do
      error = "Plugin :activerecord_preloads does not accept the :foo option. No options are allowed"
      expect { serializer.plugin(:activerecord_preloads, foo: :bar) }.to raise_error Serega::SeregaError, error
    end
  end

  describe ".records" do
    let(:serializer) { Class.new(Serega) }

    it "returns objects unchanged when the :presenter plugin is not used" do
      serializer.plugin(:activerecord_preloads)
      objects = [Object.new, Object.new]
      expect(described_class.records(serializer, objects)).to equal objects
    end

    it "returns objects unchanged when the Presenter class has no custom methods" do
      serializer.plugin(:activerecord_preloads)
      serializer.plugin(:presenter)

      objects = [Object.new, Object.new]
      expect(described_class.records(serializer, objects)).to equal objects
    end

    it "unwraps presenter-wrapped objects to their underlying records when custom presenter is used" do
      serializer.plugin(:activerecord_preloads)
      serializer.plugin(:presenter)
      serializer.presenter do
        def name
        end
      end
      record1, record2 = Object.new, Object.new

      objects = [SimpleDelegator.new(record1), SimpleDelegator.new(record2)]
      expect(described_class.records(serializer, objects)).to eq [record1, record2]
    end
  end

  describe "serialization" do
    context "with top-level preloads", :with_rollback do
      let(:user1) { AR::User.create!(first_name: "Bruce", last_name: "Wayne") }
      let(:user2) { AR::User.create!(first_name: "Clark", last_name: "Kent") }

      let(:post1) { AR::Post.create!(user: user1, text: "post1") }
      let(:post2) { AR::Post.create!(user: user2, text: "post2") }

      let(:comment1) { AR::Comment.create!(post: post1, text: "comment1") }
      let(:comment2) { AR::Comment.create!(post: post1, text: "comment2") }
      let(:comment3) { AR::Comment.create!(post: post2, text: "comment3") }
      let(:comment4) { AR::Comment.create!(post: post2, text: "comment4") }

      let(:app_serializer) do
        Class.new(Serega) do
          plugin :activerecord_preloads
        end
      end

      let(:users_serializer) do
        post_serializer = posts_serializer
        Class.new(app_serializer) do
          attribute :first_name
          attribute :last_name
          attribute :posts, serializer: -> { post_serializer }, preload: :posts
        end
      end

      let(:posts_serializer) do
        comment_serializer = comments_serializer
        Class.new(app_serializer) do
          attribute :text
          attribute :comments, serializer: -> { comment_serializer }, preload: :comments
        end
      end

      let(:comments_serializer) do
        Class.new(app_serializer) do
          attribute :text
          attribute :votes_count, preload: :votes, value: proc { |comment| comment.votes.size }
          attribute :stars, preload: :votes, value: proc { |comment|
            (comment.votes.sum(&:stars) / comment.votes.size.to_f).round(1)
          }
        end
      end

      before do
        AR::Vote.create!(comment: comment1, stars: 1)
        AR::Vote.create!(comment: comment2, stars: 2)
        AR::Vote.create!(comment: comment3, stars: 2)
        AR::Vote.create!(comment: comment4, stars: 3)
        AR::Vote.create!(comment: comment4, stars: 5)
      end

      it "serializes correctly with minimal number of queries" do
        data = nil
        expect { data = users_serializer.call(AR::User.all) }.to run_queries(4)
        expect(data).to eq [
          {
            first_name: "Bruce",
            last_name: "Wayne",
            posts: [
              {
                text: "post1",
                comments: [
                  {text: "comment1", votes_count: 1, stars: 1.0},
                  {text: "comment2", votes_count: 1, stars: 2.0}
                ]
              }
            ]
          },
          {
            first_name: "Clark",
            last_name: "Kent",
            posts: [
              {
                text: "post2",
                comments: [
                  {text: "comment3", votes_count: 1, stars: 2.0},
                  {text: "comment4", votes_count: 2, stars: 4.0}
                ]
              }
            ]
          }
        ]
      end
    end

    context "with batch loads and preloads", :with_rollback do
      let(:user1) { AR::User.create!(first_name: "Bruce", last_name: "Wayne") }
      let(:user2) { AR::User.create!(first_name: "Clark", last_name: "Kent") }

      let(:post1) { AR::Post.create!(user: user1, text: "post1") }
      let(:post2) { AR::Post.create!(user: user2, text: "post2") }

      let(:comment1) { AR::Comment.create!(post: post1, text: "comment1") }
      let(:comment2) { AR::Comment.create!(post: post1, text: "comment2") }
      let(:comment3) { AR::Comment.create!(post: post2, text: "comment3") }
      let(:comment4) { AR::Comment.create!(post: post2, text: "comment4") }

      let(:app_serializer) do
        Class.new(Serega) do
          plugin :activerecord_preloads
        end
      end

      let(:users_serializer) do
        post_serializer = posts_serializer
        Class.new(app_serializer) do
          attribute :first_name
          attribute :last_name
          attribute :posts, serializer: post_serializer,
            batch: ->(users) { AR::Post.where(user: users).group_by(&:user_id) }
        end
      end

      let(:posts_serializer) do
        comment_serializer = comments_serializer
        Class.new(app_serializer) do
          attribute :text
          attribute :comments, serializer: -> { comment_serializer }, preload: :comments
        end
      end

      let(:comments_serializer) do
        Class.new(app_serializer) do
          attribute :text
          attribute :votes_count, preload: :votes, value: proc { |comment| comment.votes.size }
          attribute :stars, preload: :votes, value: proc { |comment|
            (comment.votes.sum(&:stars) / comment.votes.size.to_f).round(1)
          }
        end
      end

      before do
        AR::Vote.create!(comment: comment1, stars: 1)
        AR::Vote.create!(comment: comment2, stars: 2)
        AR::Vote.create!(comment: comment3, stars: 2)
        AR::Vote.create!(comment: comment4, stars: 3)
        AR::Vote.create!(comment: comment4, stars: 5)
      end

      it "serializes correctly with minimal number of queries" do
        data = nil
        expect { data = users_serializer.call(AR::User.all) }.to run_queries(4)
        expect(data).to eq [
          {
            first_name: "Bruce",
            last_name: "Wayne",
            posts: [
              {
                text: "post1",
                comments: [
                  {text: "comment1", votes_count: 1, stars: 1.0},
                  {text: "comment2", votes_count: 1, stars: 2.0}
                ]
              }
            ]
          },
          {
            first_name: "Clark",
            last_name: "Kent",
            posts: [
              {
                text: "post2",
                comments: [
                  {text: "comment3", votes_count: 1, stars: 2.0},
                  {text: "comment4", votes_count: 2, stars: 4.0}
                ]
              }
            ]
          }
        ]
      end
    end
  end

  context "with batch loads and hidden preloaded attributes", :with_rollback do
    let(:user1) { AR::User.create!(first_name: "Bruce", last_name: "Wayne") }
    let(:user2) { AR::User.create!(first_name: "Clark", last_name: "Kent") }

    let(:app_serializer) do
      Class.new(Serega) do
        plugin :activerecord_preloads
      end
    end

    let(:users_serializer) do
      post_serializer = posts_serializer
      Class.new(app_serializer) do
        attribute :first_name
        attribute :last_name
        attribute :posts, serializer: post_serializer,
          batch: ->(users) { AR::Post.where(user: users).group_by(&:user_id) }
      end
    end

    let(:posts_serializer) do
      Class.new(app_serializer) do
        attribute :text
        attribute :comments, preload: :comments, hide: true
      end
    end

    before do
      AR::Post.create!(user: user1, text: "post1")
      AR::Post.create!(user: user2, text: "post2")
    end

    it "serializes correctly" do
      data = nil
      expect { data = users_serializer.call(AR::User.all) }.to run_queries(2)
      expect(data).to eq [
        {
          first_name: "Bruce",
          last_name: "Wayne",
          posts: [{text: "post1"}]
        },
        {
          first_name: "Clark",
          last_name: "Kent",
          posts: [{text: "post2"}]
        }
      ]
    end
  end

  context "with preloads through a non-AR boundary", :with_rollback do
    # A PORO wrapper sits between the AR Post and its CommentSerializer. The
    # wrapper attribute has no :preload, yet `:votes` declared deeper in
    # CommentSerializer is still bulk-preloaded on the comments at that level,
    # so there is no N+1.
    let(:post_wrapper_class) { Data.define(:post) }

    let(:user1) { AR::User.create!(first_name: "Bruce", last_name: "Wayne") }
    let(:post1) { AR::Post.create!(user: user1, text: "post1") }
    let(:comment1) { AR::Comment.create!(post: post1, text: "comment1") }
    let(:comment2) { AR::Comment.create!(post: post1, text: "comment2") }

    let(:app_serializer) { Class.new(Serega) { plugin :activerecord_preloads } }

    let(:comment_serializer) do
      Class.new(app_serializer) do
        attribute :text
        attribute :votes_count, value: proc { |c| c.votes.size }, preload: :votes
      end
    end

    let(:post_wrapper_serializer) do
      cs = comment_serializer
      Class.new(app_serializer) do
        attribute :comments, value: proc { |pw| pw.post.comments }, serializer: cs
      end
    end

    let(:user_serializer) do
      pwc = post_wrapper_class
      pws = post_wrapper_serializer
      Class.new(app_serializer) do
        attribute :first_name
        attribute :wrapped_post,
          value: proc { |u| pwc.new(post: u.posts.first) },
          serializer: pws,
          preload: :posts
      end
    end

    before do
      AR::Vote.create!(comment: comment1, stars: 3)
      AR::Vote.create!(comment: comment2, stars: 5)
    end

    it "preloads :votes through the PORO boundary without N+1" do
      data = nil
      # 3 queries: posts (auto-batch for :wrapped_post), comments (via pw.post.comments),
      # votes (auto-batch for :votes_count — enabled by the new mechanism).
      # Without the auto-batch, :votes would be loaded one-per-comment (N+1).
      expect { data = user_serializer.call([user1]) }.to run_queries(3)
      expect(data).to eq([{
        first_name: "Bruce",
        wrapped_post: {
          comments: [
            {text: "comment1", votes_count: 1},
            {text: "comment2", votes_count: 1}
          ]
        }
      }])
    end
  end

  context "with two different preloads at one level", :with_rollback do
    let(:user1) { AR::User.create!(first_name: "Bruce", last_name: "Wayne") }
    let(:post1) { AR::Post.create!(user: user1, text: "post1") }

    let(:app_serializer) { Class.new(Serega) { plugin :activerecord_preloads } }

    let(:post_serializer) do
      Class.new(app_serializer) do
        attribute :text
        attribute :author_name, preload: :user, value: proc { |p| p.user.first_name }
        attribute :comments_count, preload: :comments, value: proc { |p| p.comments.size }
      end
    end

    before do
      post1
      AR::Comment.create!(post: post1, text: "comment1")
    end

    it "preloads each attribute's own associations (one query per association)" do
      data = nil
      # posts + :user + :comments = 3 queries (each association preloaded separately)
      expect { data = post_serializer.call(AR::Post.where(id: post1.id)) }.to run_queries(3)
      expect(data).to eq([{text: "post1", author_name: "Bruce", comments_count: 1}])
    end
  end
end
