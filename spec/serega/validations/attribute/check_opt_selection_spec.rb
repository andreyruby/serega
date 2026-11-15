# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptSelection do
  subject(:check) { described_class.call(:posts, opts, block) }

  let(:post_serializer) { Class.new(Serega) { attribute :title } }
  let(:serializer) { post_serializer }
  let(:opts) { {serializer: serializer, only: :title, with: nil, except: []} }
  let(:block) { nil }

  before { allow(Serega::SeregaValidations::CheckRelationSelection).to receive(:check) }

  it "checks the attributes of the serializer class" do
    check

    expect(Serega::SeregaValidations::CheckRelationSelection).to have_received(:check)
      .with(:posts, post_serializer, {only: {title: {}}, with: {}, except: {}}, Serega::SeregaValidations::CheckPresetSelection)
  end

  context "without field selection options" do
    let(:opts) { {serializer: serializer} }

    it "checks nothing" do
      check

      expect(Serega::SeregaValidations::CheckRelationSelection).not_to have_received(:check)
    end
  end

  context "without a relation" do
    let(:opts) { {with: :title} }

    it "raises a SeregaError" do
      expect { check }
        .to raise_error Serega::SeregaError, "Option :with can be provided only together with :serializer option or a block"
    end
  end

  context "with a block" do
    let(:opts) { {except: :title} }
    let(:block) { proc {} }

    it "leaves the attributes to the check of the plan" do
      check

      expect(Serega::SeregaValidations::CheckRelationSelection).not_to have_received(:check)
    end
  end

  context "with a serializer given as a String" do
    let(:serializer) { "PostSerializer" }

    it "leaves the attributes to the check of the plan" do
      check

      expect(Serega::SeregaValidations::CheckRelationSelection).not_to have_received(:check)
    end
  end

  context "with an invalid value" do
    let(:opts) { {serializer: serializer, only: 1} }

    it "raises a SeregaError" do
      expect { check }
        .to raise_error Serega::SeregaError, "Invalid option :only => 1. Must be a Symbol, a String, an Array or a Hash of attribute names"
    end
  end
end
