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

  describe "InstanceMethods" do
    let(:serializer_class) do
      Class.new(Serega) do
        plugin :activerecord_preloads

        attribute :itself
      end
    end

    let(:serializer) { serializer_class.new }
    let(:preloader) { Serega::SeregaPlugins::ActiverecordPreloads::Preloader }

    before { allow(preloader).to receive(:preload) }

    describe "#preload_associations_to" do
      subject(:preload) { serializer.preload_associations_to(object) }

      let(:preloads) { "PRELOADS" }
      let(:object) { "OBJECT" }

      before { allow(serializer).to receive(:preloads).and_return(preloads) }

      it "adds preloads to object" do
        preload
        expect(preloader).to have_received(:preload).with(object, preloads)
      end

      context "with nil object" do
        let(:object) { nil }

        it "skips preloading" do
          preload
          expect(preloader).not_to have_received(:preload)
        end
      end

      context "with empty array" do
        let(:object) { [] }

        it "skips preloading" do
          preload
          expect(preloader).not_to have_received(:preload)
        end
      end

      context "with nothing to preload" do
        let(:preloads) { {} }

        it "skips preloading" do
          preload
          expect(preloader).not_to have_received(:preload)
        end
      end
    end

    describe "#to_h" do
      subject(:to_h) { serializer.to_h(object) }

      let(:preloads) { "PRELOADS" }
      let(:object) { "OBJECT" }

      before { allow(serializer).to receive(:preload_associations_to) }

      it "preloads associations before serialization" do
        expect(serializer.to_h(object)[:itself]).to eq(object)
        expect(serializer).to have_received(:preload_associations_to).with(object)
      end
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
end
