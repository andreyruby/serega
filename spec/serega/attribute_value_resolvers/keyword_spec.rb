# frozen_string_literal: true

RSpec.describe Serega::AttributeValueResolvers do
  describe described_class::Keyword do
    let(:keyword) { :name }

    describe "#initialize" do
      subject(:resolver) { described_class.new(keyword) }

      it "stores the keyword" do
        object = double(name: "John")
        expect(resolver.call(object)).to eq("John")
      end
    end

    describe "#call" do
      let(:resolver) { described_class.new(keyword) }

      context "when object responds to keyword method" do
        let(:object) { double(name: "John") }

        it "calls the method on object" do
          expect(resolver.call(object)).to eq("John")
        end
      end

      context "when object doesn't respond to method" do
        let(:object) { Object.new }

        it "raises NoMethodError" do
          expect { resolver.call(object) }.to raise_error(NoMethodError)
        end
      end
    end

    describe "#code" do
      subject(:code) { described_class.new(keyword).code("source") }

      it "returns the method call code" do
        expect(code).to eq "source.name"
      end

      context "with a not plain method name" do
        let(:keyword) { :"full-name" }

        it "returns nil" do
          expect(code).to be_nil
        end
      end
    end
  end
end
