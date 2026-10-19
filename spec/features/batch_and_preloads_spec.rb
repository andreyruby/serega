# frozen_string_literal: true

require "support/activerecord"
require "support/matchers/run_queries"

# rubocop:disable RSpec/LetSetup -- records stay named let!s, as a before block would hold only half of them
RSpec.describe Serega, :with_rollback do
  subject(:result) { user_serializer.to_h(object) }

  let!(:user1) { AR::User.create!(first_name: "Bruce") }
  let!(:user2) { AR::User.create!(first_name: "Clark") }
  let!(:post) { AR::Post.create!(user: user1, text: "post") }
  let!(:comment1) { AR::Comment.create!(post: post, text: "comment1") }
  let!(:comment2) { AR::Comment.create!(post: post, text: "comment2") }
  let!(:vote) { AR::Vote.create!(comment: comment1) }

  let(:object) { AR::User.all }
  let(:auto_preload) { false }

  let(:preload_posts) { {preload: :posts} }
  let(:preload_comments) { {preload: :comments} }
  let(:preload_votes_count) { {preload: :votes, value: proc { |comment| comment.votes.size }} }

  let(:batch_posts) { {batch: ->(users) { AR::Post.where(user: users).group_by(&:user_id) }, many: true} }
  let(:batch_comments) { {batch: ->(posts) { AR::Comment.where(post: posts).group_by(&:post_id) }, many: true} }
  let(:batch_votes_count) { {batch: ->(comments) { AR::Vote.where(comment: comments).group(:comment_id).count }, default: 0} }

  let(:app_serializer) do
    auto_preload = self.auto_preload

    Class.new(Serega) do
      plugin :activerecord_preloads
      config.auto_preload = auto_preload
    end
  end

  let(:comment_serializer) do
    votes_count_options = self.votes_count_options

    Class.new(app_serializer) do
      attribute :text
      attribute :votes_count, **votes_count_options
    end
  end

  let(:post_serializer) do
    comment_serializer = self.comment_serializer
    comments_options = self.comments_options

    Class.new(app_serializer) do
      attribute :text
      attribute :comments, serializer: comment_serializer, **comments_options
    end
  end

  let(:user_serializer) do
    post_serializer = self.post_serializer
    posts_options = self.posts_options

    Class.new(app_serializer) do
      attribute :first_name
      attribute :posts, serializer: post_serializer, **posts_options
    end
  end

  let(:serialized_user1) do
    {
      first_name: "Bruce",
      posts: [{text: "post", comments: [{text: "comment1", votes_count: 1}, {text: "comment2", votes_count: 0}]}]
    }
  end

  let(:serialized_user2) { {first_name: "Clark", posts: []} }

  describe "loading each relation with a preload or a batch loader" do
    context "with preloaded posts, comments and votes" do
      let(:posts_options) { preload_posts }
      let(:comments_options) { preload_comments }
      let(:votes_count_options) { preload_votes_count }

      it "serializes the users in one query per relation" do
        expect { result }.to run_queries(4)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end

    context "with batch loaded posts and preloaded comments and votes" do
      let(:posts_options) { batch_posts }
      let(:comments_options) { preload_comments }
      let(:votes_count_options) { preload_votes_count }

      it "serializes the users in one query per relation" do
        expect { result }.to run_queries(4)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end

    context "with batch loaded posts and comments and preloaded votes" do
      let(:posts_options) { batch_posts }
      let(:comments_options) { batch_comments }
      let(:votes_count_options) { preload_votes_count }

      it "serializes the users in one query per relation" do
        expect { result }.to run_queries(4)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end

    context "with batch loaded posts, preloaded comments and batch loaded votes" do
      let(:posts_options) { batch_posts }
      let(:comments_options) { preload_comments }
      let(:votes_count_options) { batch_votes_count }

      it "serializes the users in one query per relation" do
        expect { result }.to run_queries(4)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end

    context "with batch loaded posts, comments and votes" do
      let(:posts_options) { batch_posts }
      let(:comments_options) { batch_comments }
      let(:votes_count_options) { batch_votes_count }

      it "serializes the users in one query per relation" do
        expect { result }.to run_queries(4)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end

    context "with preloaded posts and batch loaded comments and votes" do
      let(:posts_options) { preload_posts }
      let(:comments_options) { batch_comments }
      let(:votes_count_options) { batch_votes_count }

      it "serializes the users in one query per relation" do
        expect { result }.to run_queries(4)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end

    context "with preloaded posts and comments and batch loaded votes" do
      let(:posts_options) { preload_posts }
      let(:comments_options) { preload_comments }
      let(:votes_count_options) { batch_votes_count }

      it "serializes the users in one query per relation" do
        expect { result }.to run_queries(4)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end

    context "with preloaded posts, batch loaded comments and preloaded votes" do
      let(:posts_options) { preload_posts }
      let(:comments_options) { batch_comments }
      let(:votes_count_options) { preload_votes_count }

      it "serializes the users in one query per relation" do
        expect { result }.to run_queries(4)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end

    context "when auto_preload sets the preloads of posts and comments" do
      let(:auto_preload) { true }
      let(:posts_options) { {} }
      let(:comments_options) { {} }
      let(:votes_count_options) { batch_votes_count }

      it "serializes the users in one query per relation" do
        expect { result }.to run_queries(4)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end
  end

  describe "serializing different objects with preloads" do
    let(:posts_options) { preload_posts }
    let(:comments_options) { preload_comments }
    let(:votes_count_options) { preload_votes_count }

    context "with a record" do
      let!(:object) { AR::User.find(user1.id) }

      it "serializes the user in one query per relation" do
        expect { result }.to run_queries(3)
        expect(result).to eq serialized_user1
      end
    end

    context "with a record with a post created through the association" do
      let!(:object) { AR::User.find(user1.id).tap { |user| user.posts.create!(text: "new post") } }

      it "serializes the user with the created post" do
        expect { result }.to run_queries(3)
        expect(result).to eq(first_name: "Bruce", posts: [*serialized_user1[:posts], {text: "new post", comments: []}])
      end
    end

    context "with an array of records" do
      let!(:object) { AR::User.all.to_a }

      it "serializes the users in one query per relation" do
        expect { result }.to run_queries(3)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end

    context "with a loaded relation" do
      let!(:object) { AR::User.all.load }

      it "serializes the users in one query per relation" do
        expect { result }.to run_queries(3)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end

    context "with a relation that includes the posts" do
      let(:object) { AR::User.includes(:posts) }

      it "serializes the users in one query per relation" do
        expect { result }.to run_queries(4)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end

    context "with a loaded relation that includes the posts" do
      let!(:object) { AR::User.includes(:posts).load }

      it "serializes the users without loading the posts again" do
        expect { result }.to run_queries(2)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end
  end

  describe "serializing different objects with batch loaders" do
    let(:posts_options) { batch_posts }
    let(:comments_options) { batch_comments }
    let(:votes_count_options) { batch_votes_count }

    context "with a record" do
      let!(:object) { AR::User.find(user1.id) }

      it "serializes the user in one query per relation" do
        expect { result }.to run_queries(3)
        expect(result).to eq serialized_user1
      end
    end

    context "with an array of records" do
      let!(:object) { AR::User.all.to_a }

      it "serializes the users in one query per relation" do
        expect { result }.to run_queries(3)
        expect(result).to eq [serialized_user1, serialized_user2]
      end
    end
  end
end
# rubocop:enable RSpec/LetSetup
