# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::CamelCase do
  describe ".call" do
    subject(:result) { described_class.call(name) }

    let(:name) { :first_name }

    it "returns the name in camelCase as a Symbol" do
      expect(result).to eq :firstName
    end

    context "with a String name" do
      let(:name) { "first_name" }

      it "returns the name in camelCase as a Symbol" do
        expect(result).to eq :firstName
      end
    end

    context "with digits after underscores" do
      let(:name) { :line_2_text }

      it "drops the underscores before the digits" do
        expect(result).to eq :line2Text
      end
    end

    context "with uppercase letters" do
      let(:name) { :user_ID_camelCase }

      it "keeps the uppercase letters and the underscores before them" do
        expect(result).to eq :user_IDCamelCase
      end
    end

    context "with leading, double and trailing underscores" do
      let(:name) { :_a__b_ }

      it "keeps the underscores that come before no letter or digit" do
        expect(result).to eq :A_B_
      end
    end

    context "without underscores" do
      let(:name) { :"first-name" }

      it "returns the name as it is" do
        expect(result).to eq :"first-name"
      end
    end
  end
end
