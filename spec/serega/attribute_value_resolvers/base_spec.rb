# frozen_string_literal: true

RSpec.describe Serega::AttributeValueResolvers::Base do
  let(:resolver) { described_class.new }

  describe "#code" do
    it "returns nil" do
      expect(resolver.code("source")).to be_nil
    end
  end

  describe "#object_method" do
    it "returns nil" do
      expect(resolver.object_method).to be_nil
    end
  end

  describe "#const?" do
    it "returns false" do
      expect(resolver.const?).to be false
    end
  end
end
