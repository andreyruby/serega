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

  describe "#many" do
    subject(:many) { point_for(serializer, :posts).many }

    let(:post_serializer) do
      post_many = post_config_many
      Class.new(base) do
        config.many = post_many
        attribute :title
      end
    end

    let(:serializer) do
      opts = attribute_opts
      posts = post_serializer
      Class.new(base) { attribute :posts, serializer: posts, **opts }
    end

    let(:attribute_opts) { {} }
    let(:post_config_many) { nil }

    context "with the :many option" do
      let(:attribute_opts) { {many: true} }
      let(:post_config_many) { false }

      it "returns the option" do
        expect(many).to be true
      end
    end

    context "when the relation serializer sets config.many" do
      let(:post_config_many) { false }

      it "returns config.many of the relation serializer" do
        expect(many).to be false
      end
    end

    context "without the :many option and config.many" do
      it "returns nil" do
        expect(many).to be_nil
      end
    end

    context "with an attribute without a serializer" do
      subject(:many) { point_for(serializer, :title).many }

      let(:serializer) { Class.new(base) { attribute :title } }

      it "returns nil" do
        expect(many).to be_nil
      end
    end
  end

  describe "#nil_as_empty_list?" do
    subject(:nil_as_empty_list) { point_for(serializer, :posts).nil_as_empty_list? }

    let(:post_serializer) do
      Class.new(base) do
        config.many = true
        attribute :title
      end
    end

    let(:serializer) do
      opts = attribute_opts
      posts = post_serializer
      Class.new(base) { attribute :posts, serializer: posts, **opts }
    end

    let(:attribute_opts) { {} }

    context "when the relation serializer sets config.many to true" do
      it "returns true" do
        expect(nil_as_empty_list).to be true
      end
    end

    context "with the :many option" do
      let(:attribute_opts) { {many: false} }

      it "returns false" do
        expect(nil_as_empty_list).to be false
      end
    end

    context "with the :default option" do
      let(:attribute_opts) { {default: nil} }

      it "returns false" do
        expect(nil_as_empty_list).to be false
      end
    end
  end
end
