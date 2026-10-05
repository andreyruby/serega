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

  describe "#call" do
    subject(:result) { run.call(plan, object, many: many) }

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

  describe "#object_group" do
    it "returns an object group of the plan serializer" do
      object_group = run.object_group(plan)

      expect(object_group).to be_a user_serializer::SeregaObjectGroup
      expect(object_group.plan).to equal plan
      expect(object_group.run).to equal run
    end

    it "returns the same group for the same plan" do
      expect(run.object_group(plan)).to equal run.object_group(plan)
    end

    it "returns separate groups for different plans" do
      other_plan = user_serializer::SeregaPlan.new(nil, {})

      expect(run.object_group(plan)).not_to equal run.object_group(other_plan)
    end
  end
end
