# frozen_string_literal: true

RSpec.describe Serega do
  describe "config.compact" do
    subject(:result) { user_serializer.public_send(serialization_method, users) }

    let(:serialization_method) { :to_h }
    let(:user_class) { Struct.new(:id, :name, :avatar, :posts) }
    let(:post_class) { Struct.new(:title, :body) }

    let(:post_serializer) do
      Class.new(Serega) do
        config.compact = true

        attribute :title
        attribute :body
      end
    end

    let(:user_serializer) do
      posts = post_serializer

      Class.new(Serega) do
        config.compact = true

        attribute :id
        attribute :name
        attribute :avatar, serializer: posts
        attribute :posts, serializer: posts, many: true
      end
    end

    let(:users) do
      [
        user_class.new(id: 1, name: nil, avatar: nil, posts: [post_class.new("Hello", nil)]),
        user_class.new(id: 2, name: "Bob", avatar: nil, posts: [])
      ]
    end

    it "leaves out the keys with nil values and keeps empty lists" do
      expect(result).to eq [{id: 1, posts: [{title: "Hello"}]}, {id: 2, name: "Bob", posts: []}]
    end

    context "with to_struct" do
      let(:serialization_method) { :to_struct }

      it "keeps the members with nil values" do
        expect(result.first.to_h).to eq(id: 1, name: nil, avatar: nil, posts: [post_serializer.to_struct(users.first.posts.first)])
      end
    end

    context "when a nested serializer does not compact" do
      let(:post_serializer) do
        Class.new(Serega) do
          attribute :title
          attribute :body
        end
      end

      it "keeps the nil values of the nested serializer" do
        expect(result.first).to eq(id: 1, posts: [{title: "Hello", body: nil}])
      end
    end

    context "with a conditional attribute" do
      let(:user_serializer) do
        Class.new(Serega) do
          config.compact = true

          attribute :id
          attribute :name, unless: proc { |user| user.id == 2 }
        end
      end

      it "leaves out the nil values and the skipped attributes" do
        expect(result).to eq [{id: 1}, {id: 2}]
      end
    end
  end
end
