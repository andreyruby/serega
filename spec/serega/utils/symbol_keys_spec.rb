# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::SymbolKeys do
  subject(:result) { described_class.call(hash) }

  let(:hash) { {only: :first_name, with: :email} }

  it "returns the given Hash" do
    expect(result).to equal hash
  end

  context "with a String key" do
    let(:hash) { {"only" => :first_name, :with => :email} }

    it "returns a copy with Symbol keys" do
      expect(result).to eq(only: :first_name, with: :email)
    end
  end
end
