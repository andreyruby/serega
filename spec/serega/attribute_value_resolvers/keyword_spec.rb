# frozen_string_literal: true

RSpec.describe Serega::AttributeValueResolvers do
  describe described_class::KeywordResolver do
    let(:keyword) { :name }

    describe ".get" do
      it "creates Keyword resolver with given keyword" do
        resolver = described_class.get(keyword)
        expect(resolver).to be_a(Serega::AttributeValueResolvers::Keyword)
      end
    end
  end

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
  end
end
