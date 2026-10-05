# frozen_string_literal: true

RSpec.describe Serega::SeregaEngine::Run do
  subject(:run) { described_class.new(mode: mode, context: context) }

  let(:mode) { :hash }
  let(:context) { {locale: :en} }
  let(:post_serializer) { Class.new(Serega) { attribute :title } }

  let(:user_serializer) do
    child = post_serializer
    Class.new(Serega) do
      attribute :name
      attribute :posts, serializer: child
    end
  end

  let(:plan) { user_serializer::SeregaPlan.new(nil, {}) }

  describe ".call" do
    subject(:result) { described_class.call(plan, object, many: many, mode: mode, context: context) }

    let(:post) { double(title: "Hello") }
    let(:user) { double(name: "Ann", posts: [post]) }
    let(:object) { user }
    let(:many) { false }

    it "serializes the object and its related objects" do
      expect(result).to eq(name: "Ann", posts: [{title: "Hello"}])
    end

    context "with a collection" do
      let(:object) { [user, user] }
      let(:many) { true }

      it "serializes every object" do
        expect(result).to eq [{name: "Ann", posts: [{title: "Hello"}]}, {name: "Ann", posts: [{title: "Hello"}]}]
      end
    end

    context "with nil" do
      let(:object) { nil }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "with the :struct mode" do
      let(:mode) { :struct }

      it "serializes the object to a Struct" do
        post_struct_class = post_serializer::SeregaResultBuilder.struct_class_for(%i[title])

        expect(result.to_h).to eq(name: "Ann", posts: [post_struct_class.new("Hello")])
      end
    end
  end

  describe "#mode" do
    it "returns the serialization mode" do
      expect(run.mode).to eq :hash
    end
  end

  describe "#context" do
    it "returns the serialization context" do
      expect(run.context).to equal context
    end
  end

  describe "#add_object_group" do
    subject(:object_group) { run.add_object_group(plan, [user], [Serega::SeregaEngine::SINGLE_OBJECT]) }

    let(:user) { double }

    it "returns a new object group of the plan serializer" do
      expect(object_group).to be_a user_serializer::SeregaObjectGroup
      expect(object_group.plan).to equal plan
      expect(object_group.run).to equal run
      expect(object_group.objects).to eq [user]
      expect(object_group.references).to eq [Serega::SeregaEngine::SINGLE_OBJECT]
    end
  end

  describe "#collect" do
    subject(:reference) { run.collect(object, many, objects) }

    let(:objects) { [user1] }
    let(:user1) { double }
    let(:user2) { double }
    let(:object) { [user2, user2] }
    let(:many) { nil }

    it "adds the collection and returns the count of its objects" do
      expect(reference).to eq 2
      expect(objects).to eq [user1, user2, user2]
    end

    context "with one object" do
      let(:object) { user2 }

      it "adds the object and returns SINGLE_OBJECT" do
        expect(reference).to eq Serega::SeregaEngine::SINGLE_OBJECT
        expect(objects).to eq [user1, user2]
      end
    end

    context "with nil" do
      let(:object) { nil }

      it "adds no objects" do
        expect(reference).to be_nil
        expect(objects).to eq [user1]
      end
    end

    context "when many is true and the object is not a collection" do
      let(:object) { user2 }
      let(:many) { true }

      it "adds the object and returns the count 1" do
        expect(reference).to eq 1
        expect(objects).to eq [user1, user2]
      end
    end

    context "when many is false and the object is a collection" do
      let(:many) { false }

      it "adds the collection as one object" do
        expect(reference).to eq Serega::SeregaEngine::SINGLE_OBJECT
        expect(objects).to eq [user1, [user2, user2]]
      end
    end
  end
end
