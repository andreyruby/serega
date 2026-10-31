# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::RubyLiteral do
  describe ".literal?" do
    subject(:literal) { described_class.literal?(value) }

    context "with a String" do
      let(:value) { "text" }

      it "returns true" do
        expect(literal).to be true
      end
    end

    context "with a finite Float" do
      let(:value) { 1.5 }

      it "returns true" do
        expect(literal).to be true
      end
    end

    context "with an infinite Float" do
      let(:value) { Float::INFINITY }

      it "returns false" do
        expect(literal).to be false
      end
    end

    context "with an object" do
      let(:value) { Rational(1, 2) }

      it "returns false" do
        expect(literal).to be false
      end
    end
  end

  describe ".code" do
    subject(:code) { described_class.code(value) }

    context "with a String" do
      let(:value) { "text" }

      it "returns the frozen String literal" do
        expect(code).to eq '"text".freeze'
      end
    end

    context "with a Symbol" do
      let(:value) { :text }

      it "returns the Symbol literal" do
        expect(code).to eq ":text"
      end
    end
  end
end
