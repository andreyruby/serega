# frozen_string_literal: true

RSpec.describe Serega do
  describe "presets" do
    subject(:result) { serializer.to_h(user, preset: preset, only: only, with: with, except: except) }

    let(:serializer) { user_serializer }

    let(:post_serializer) do
      Class.new(described_class) do
        attribute :title
        attribute :body, hide: true
      end
    end

    let(:user_serializer) do
      posts = post_serializer

      Class.new(described_class) do
        attribute :name
        attribute :email, hide: true
        attribute :posts, serializer: posts, many: true, hide: true

        preset :card, only: [:name, {posts: :title}]
        preset :profile, preset: :card, with: {posts: :body}
        preset :contacts, with: :email
      end
    end

    let(:user) { Struct.new(:name, :email, :posts).new("Ann", "ann@example.com", [post]) }
    let(:post) { Struct.new(:title, :body).new("Hello", "Text") }
    let(:preset) { :card }
    let(:only) { nil }
    let(:with) { nil }
    let(:except) { nil }

    it "serializes the fields of the preset" do
      expect(result).to eq(name: "Ann", posts: [{title: "Hello"}])
    end

    context "with a preset that includes another preset" do
      let(:preset) { :profile }

      it "serializes the fields of both presets" do
        expect(result).to eq(name: "Ann", posts: [{title: "Hello", body: "Text"}])
      end
    end

    context "with several presets" do
      let(:preset) { %i[card contacts] }

      it "serializes the fields of all presets" do
        expect(result).to eq(name: "Ann", email: "ann@example.com", posts: [{title: "Hello"}])
      end
    end

    context "with a String preset name" do
      let(:preset) { "card" }

      it "serializes the fields of the preset" do
        expect(result).to eq(name: "Ann", posts: [{title: "Hello"}])
      end
    end

    context "with only" do
      let(:only) { {posts: :body} }

      it "adds the fields to the fields of the preset" do
        expect(result).to eq(name: "Ann", posts: [{title: "Hello", body: "Text"}])
      end
    end

    context "with with" do
      let(:with) { :email }

      it "adds the hidden fields to the fields of the preset" do
        expect(result).to eq(name: "Ann", email: "ann@example.com", posts: [{title: "Hello"}])
      end
    end

    context "with except" do
      let(:except) { {posts: :title} }

      it "removes the fields from the fields of the preset" do
        expect(result).to eq(name: "Ann", posts: [{}])
      end
    end

    context "with an undefined preset" do
      let(:preset) { :admin }

      it "raises a PresetNotExist error" do
        expect { result }.to raise_error Serega::PresetNotExist, "Preset :admin is not defined in #{user_serializer}"
      end
    end

    context "with a subclass" do
      let(:serializer) { Class.new(user_serializer) }

      it "serializes the fields of the inherited preset" do
        expect(result).to eq(name: "Ann", posts: [{title: "Hello"}])
      end
    end

    context "when a preset with the same name is defined again" do
      before { user_serializer.preset :card, only: :email }

      it "serializes the fields of the new preset" do
        expect(result).to eq(email: "ann@example.com")
      end
    end

    context "when an included preset is defined again" do
      let(:preset) { :profile }

      before { user_serializer.preset :card, only: [:email, {posts: :title}] }

      it "serializes the fields of the new included preset" do
        expect(result).to eq(email: "ann@example.com", posts: [{title: "Hello", body: "Text"}])
      end
    end

    context "when a subclass defines an included preset again" do
      let(:serializer) { Class.new(user_serializer) { preset :card, only: [:email, {posts: :title}] } }
      let(:preset) { :profile }

      it "serializes the fields of the included preset of the subclass" do
        expect(result).to eq(email: "ann@example.com", posts: [{title: "Hello", body: "Text"}])
        expect(user_serializer.to_h(user, preset: preset)).to eq(name: "Ann", posts: [{title: "Hello", body: "Text"}])
      end
    end

    context "when a preset names a nested attribute of a serializer resolved later" do
      let(:serializer) do
        posts = post_serializer

        Class.new(described_class) do
          attribute :posts, serializer: -> { posts }, many: true
          preset :broken, only: {posts: :rating}
        end
      end

      let(:preset) { :broken }

      it "raises an AttributeNotExist error on the serialization" do
        expect { result }.to raise_error Serega::AttributeNotExist, "Not existing attributes: posts(rating)"
      end
    end

    context "when a shareable serializer names a relation serializer defined later" do
      # rubocop:disable RSpec/LetSetup -- the serializer locks before its relation serializer is defined
      let!(:serializer) do
        Class.new(described_class) do
          attribute :posts, serializer: "PresetsSpecPostSerializer", many: true
          preset :titles, only: {posts: :title}
          make_shareable!
        end
      end
      # rubocop:enable RSpec/LetSetup

      let(:preset) { :titles }

      before { stub_const("PresetsSpecPostSerializer", post_serializer) }

      it "serializes the fields of the preset" do
        expect(result).to eq(posts: [{title: "Hello"}])
      end
    end

    context "when the serializer was used for serialization" do
      before { user_serializer.to_h(user) }

      it "raises a SeregaError on a new preset" do
        expect { user_serializer.preset :admin, with: :email }
          .to raise_error Serega::SeregaError, "#{user_serializer} can not be changed after it was used for serialization"
      end
    end
  end

  describe "a relation preset" do
    subject(:result) { serializer.to_h(user, only: only, with: with, except: except) }

    let(:serializer) { user_serializer }

    let(:post_serializer) do
      Class.new(described_class) do
        attribute :id
        attribute :title
        attribute :body

        preset :summary, only: [:id, :title]
      end
    end

    let(:user_serializer) do
      posts = post_serializer

      Class.new(described_class) do
        attribute :name
        attribute :posts, serializer: posts, many: true, preset: :summary

        preset :card, only: [:name, :posts]
      end
    end

    let(:user) { Struct.new(:name, :posts).new("Ann", [post]) }
    let(:post) { Struct.new(:id, :title, :body).new(1, "Hello", "Text") }
    let(:only) { nil }
    let(:with) { nil }
    let(:except) { nil }

    it "serializes the fields of the preset" do
      expect(result).to eq(name: "Ann", posts: [{id: 1, title: "Hello"}])
    end

    context "with only that names the relation" do
      let(:only) { :posts }

      it "serializes the fields of the preset" do
        expect(result).to eq(posts: [{id: 1, title: "Hello"}])
      end
    end

    context "with with that names the hidden relation" do
      let(:serializer) do
        posts = post_serializer
        Class.new(described_class) { attribute :posts, serializer: posts, many: true, preset: :summary, hide: true }
      end

      let(:with) { :posts }

      it "serializes the fields of the preset" do
        expect(result).to eq(posts: [{id: 1, title: "Hello"}])
      end
    end

    context "with with that names a nested field" do
      let(:with) { {posts: :body} }

      it "adds the field to the fields of the preset" do
        expect(result).to eq(name: "Ann", posts: [{id: 1, title: "Hello", body: "Text"}])
      end
    end

    context "with except that names a nested field" do
      let(:except) { {posts: :title} }

      it "removes the field from the fields of the preset" do
        expect(result).to eq(name: "Ann", posts: [{id: 1}])
      end
    end

    context "with only that names a nested field" do
      let(:only) { {posts: :id} }

      it "serializes the fields of the preset" do
        expect(result).to eq(posts: [{id: 1, title: "Hello"}])
      end
    end

    context "with except that names the relation" do
      let(:except) { :posts }

      it "does not serialize the relation" do
        expect(result).to eq(name: "Ann")
      end
    end

    context "with except that names a nested relation" do
      subject(:result) { serializer.to_h(comment, except: {user: :posts}) }

      let(:serializer) do
        users = user_serializer
        Class.new(described_class) { attribute :user, serializer: users, many: false }
      end

      let(:comment) { Struct.new(:user).new(user) }

      it "serializes the parent relation without the nested relation" do
        expect(result).to eq(user: {name: "Ann"})
      end
    end

    context "with a preset of the parent serializer that names the relation" do
      subject(:result) { serializer.to_h(user, preset: :card) }

      it "serializes the fields of the relation preset" do
        expect(result).to eq(name: "Ann", posts: [{id: 1, title: "Hello"}])
      end
    end

    context "with an undefined preset of a serializer resolved later" do
      let(:serializer) do
        posts = post_serializer
        Class.new(described_class) { attribute :posts, serializer: -> { posts }, many: true, preset: :full }
      end

      it "raises PresetNotExist" do
        expect { result }.to raise_error Serega::PresetNotExist, "Preset :full is not defined in #{post_serializer}"
      end
    end
  end
end
