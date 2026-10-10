# frozen_string_literal: true

RSpec.describe Serega::SeregaEngine::Run do
  subject(:run) { described_class.new(mode: mode, context: context) }

  let(:mode) { :hash }
  let(:context) { {locale: :en} }
  let(:post_serializer) { Class.new(Serega) { attribute :title }.freeze }

  let(:user_serializer) do
    child = post_serializer
    Class.new(Serega) do
      attribute :name
      attribute :posts, serializer: child
      freeze
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

  describe "#new_source_group" do
    subject(:source_group) { run.new_source_group(plan, [user], [Serega::SeregaEngine::Pulls::SINGLE_SOURCE]) }

    let(:user) { double }

    it "returns a new source group of the plan serializer" do
      expect(source_group).to be_a user_serializer::SeregaSourceGroup
      expect(source_group.plan).to equal plan
      expect(source_group.run).to equal run
      expect(source_group.sources).to eq [user]
      expect(source_group.pulls).to eq [Serega::SeregaEngine::Pulls::SINGLE_SOURCE]
    end
  end
end
