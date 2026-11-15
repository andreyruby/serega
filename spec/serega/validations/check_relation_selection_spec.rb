# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::CheckRelationSelection do
  let(:post_serializer) { Class.new(Serega) { attribute :title } }

  describe ".call" do
    subject(:check) { described_class.call(attribute, post_serializer) }

    let(:attribute) { user_serializer.attributes[:posts] }
    let(:only) { :subtitle }

    let(:user_serializer) do
      posts = post_serializer
      relation_only = only
      Class.new(Serega) { attribute :posts, serializer: -> { posts }, only: relation_only }
    end

    it "raises AttributeNotExist that names the relation" do
      expect { check }.to raise_error(Serega::AttributeNotExist, "Relation :posts names not existing attributes: subtitle") do |error|
        expect(error.serializer).to be post_serializer
        expect(error.attributes).to eq ["subtitle"]
      end
    end

    context "with existing attributes" do
      let(:only) { :title }

      it "accepts the options" do
        expect { check }.not_to raise_error
      end
    end

    context "with a serializer class" do
      # The double answers only #initials, thus reading the options raises
      let(:attribute) { instance_double(Serega::SeregaAttribute, initials: {opts: {serializer: post_serializer}}) }

      it "checks nothing, as the definition checked the options" do
        expect { check }.not_to raise_error
      end
    end
  end

  describe ".check" do
    subject(:check) { described_class.check(:posts, post_serializer, selection, Serega::SeregaValidations::CheckSelection) }

    let(:selection) { {only: {title: {}}, with: {}, except: {}} }

    it "accepts existing attributes" do
      expect { check }.not_to raise_error
    end

    context "with an unknown attribute" do
      let(:selection) { {only: {}, with: {body: {}}, except: {}} }

      it "raises AttributeNotExist that names the relation" do
        expect { check }.to raise_error(Serega::AttributeNotExist, "Relation :posts names not existing attributes: body")
      end
    end
  end
end
