# frozen_string_literal: true

RSpec.describe Serega::AttributeValueResolvers do
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
