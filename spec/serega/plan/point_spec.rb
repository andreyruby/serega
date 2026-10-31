# frozen_string_literal: true

RSpec.describe Serega::SeregaPlan::Point do
  let(:base) { Class.new(Serega) }

  def point_for(serializer, name)
    default_plan(serializer).points.find { |point| point.name == name }
  end

  describe "#initialize" do
    subject(:point) { described_class.new(plan, attribute, :author, child_selection) }

    let(:plan) { default_plan(serializer) }
    let(:serializer) { Class.new(base) { attribute :author } }
    let(:attribute) { serializer.attributes[:author] }
    let(:child_serializer) { Class.new(base) }
    let(:child_selection) { Serega::SeregaPlan::Selection.new(child_serializer, {}) }

    it "keeps the preloads" do
      expect(point.preloads).to eq :author
    end

    it "makes the child plan of the child selection" do
      expect(point.child_plan).to have_attributes(serializer_class: child_serializer, parent_plan_point: point)
      expect(point.collection_classes).to eq({})
    end

    context "without a child selection" do
      let(:child_selection) { nil }

      it "has no child plan and no collection classes" do
        expect(point.child_plan).to be_nil
        expect(point.collection_classes).to be_nil
      end
    end
  end

  describe "#path" do
    subject(:path) { comment_point.path }

    let(:comment_serializer) { Class.new(base) { attribute :text } }

    let(:post_serializer) do
      child = comment_serializer
      Class.new(base) { attribute :comments, serializer: child }
    end

    let(:user_serializer) do
      child = post_serializer
      Class.new(base) { attribute :posts, serializer: child }
    end

    let(:comment_point) { point_for(user_serializer, :posts).child_plan.points.first }

    it "returns the attribute names from the root plan down to the point" do
      expect(path).to eq %i[posts comments]
    end
  end

  describe "#conditional?" do
    subject(:conditional) { point_for(serializer, :email).conditional? }

    let(:serializer) do
      opts = attribute_opts
      Class.new(base) { attribute :email, **opts }
    end

    context "without conditions" do
      let(:attribute_opts) { {} }

      it "returns false" do
        expect(conditional).to be false
      end
    end

    %i[if unless if_value unless_value].each do |option|
      context "with the :#{option} condition" do
        let(:attribute_opts) { {option => :present?} }

        it "returns true" do
          expect(conditional).to be true
        end
      end
    end
  end
end
