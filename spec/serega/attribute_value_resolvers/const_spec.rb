# frozen_string_literal: true

RSpec.describe Serega::AttributeValueResolvers do
  describe described_class::ConstResolver do
    describe ".get" do
      let(:const_value) { "test_value" }

      it "creates Const resolver with given value" do
        resolver = described_class.get(const_value)
        expect(resolver).to be_a(Serega::AttributeValueResolvers::Const)
        expect(resolver.call).to eq("test_value")
      end
    end
  end

  describe described_class::Const do
    let(:const_value) { "hello world" }

    describe "#initialize" do
      subject(:resolver) { described_class.new(const_value) }

      it "stores the constant value" do
        expect(resolver.call).to eq("hello world")
      end
    end

    describe "#call" do
      let(:resolver) { described_class.new(const_value) }

      it "returns the constant value" do
        expect(resolver.call).to equal const_value
      end
    end
  end
end
