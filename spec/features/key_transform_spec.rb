# frozen_string_literal: true

RSpec.describe Serega do
  describe "config.key_transform" do
    let(:base_serializer) do
      key_transform = transform
      Class.new(described_class) { config.key_transform = key_transform }
    end

    let(:post_serializer) { Class.new(base_serializer) { attribute :created_at } }

    let(:user_serializer) do
      posts = post_serializer
      Class.new(base_serializer) do
        attribute :first_name
        attribute :recent_posts, serializer: posts, many: true
      end
    end

    let(:post) { Struct.new(:created_at).new("2026-11-14") }
    let(:user) { Struct.new(:first_name, :recent_posts).new("Ann", [post]) }

    context "with :camel_case" do
      let(:transform) { :camel_case }

      it "serializes the keys in camelCase" do
        expect(user_serializer.to_h(user)).to eq(firstName: "Ann", recentPosts: [{createdAt: "2026-11-14"}])
      end

      it "names the attributes in camelCase" do
        expect(user_serializer.attributes.keys).to eq %i[firstName recentPosts]
        expect(user_serializer.to_h(user, only: {recentPosts: :createdAt})).to eq(recentPosts: [{createdAt: "2026-11-14"}])
      end

      it "names the Struct members in camelCase" do
        expect(user_serializer.to_struct(user).members).to eq %i[firstName recentPosts]
      end
    end

    context "with a callable that returns Strings" do
      let(:transform) { ->(name) { name.to_s.tr("_", "-") } }

      it "serializes the String keys" do
        expect(user_serializer.to_h(user)).to eq("first-name" => "Ann", "recent-posts" => [{"created-at" => "2026-11-14"}])
      end

      it "selects the fields by the keys as Symbols" do
        expect(user_serializer.to_h(user, only: :"first-name")).to eq("first-name" => "Ann")
      end

      it "names the Struct and Data members by the keys as Symbols" do
        struct = user_serializer.to_struct(user)
        data = user_serializer.to_data(user)

        expect(struct.members).to eq %i[first-name recent-posts]
        expect(struct[:"recent-posts"][0][:"created-at"]).to eq "2026-11-14"

        expect(data.class.members).to eq %i[first-name recent-posts]
        expect(data.public_send(:"recent-posts")[0].public_send(:"created-at")).to eq "2026-11-14"
      end
    end
  end
end
