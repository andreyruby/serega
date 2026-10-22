# frozen_string_literal: true

RSpec.describe Serega::AttributeNormalizers::BatchOption do
  subject(:option) { described_class.new(batch, :likes_count) }

  let(:batch) { true }

  it "uses the loader named after the attribute" do
    expect(option).to have_attributes(use: :likes_count, id: nil, inline?: false, loader_names: [:likes_count])
  end

  context "with a loader name" do
    let(:batch) { "likes" }

    it "uses the named loader" do
      expect(option).to have_attributes(use: "likes", id: nil, inline?: false, loader_names: [:likes])
    end
  end

  context "with a callable" do
    let(:batch) { proc {} }

    it "uses the callable as an inline loader named after the attribute" do
      expect(option).to have_attributes(use: batch, id: nil, inline?: true, loader_names: [:likes_count])
    end
  end

  context "with a Hash with only :id" do
    let(:batch) { {id: :uuid} }

    it "uses the loader named after the attribute and the given id" do
      expect(option).to have_attributes(use: :likes_count, id: :uuid, loader_names: [:likes_count])
    end
  end

  context "with a Hash with several loaders in :use" do
    let(:batch) { {use: %i[likes views]} }

    it "uses the given loaders" do
      expect(option).to have_attributes(use: %i[likes views], id: nil, loader_names: %i[likes views])
    end
  end
end
