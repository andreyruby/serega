# frozen_string_literal: true

RSpec.describe Serega::SeregaFormatter do
  subject(:formatted) { described_class.new(callable).call(1234, context) }

  let(:context) { {currency: "EUR"} }

  context "with a value parameter" do
    let(:callable) { ->(cents) { cents / 100.0 } }

    it "formats the value" do
      expect(formatted).to eq 12.34
    end
  end

  context "with value and context parameters" do
    let(:callable) { ->(cents, context) { "#{cents / 100.0} #{context[:currency]}" } }

    it "formats the value with the context" do
      expect(formatted).to eq "12.34 EUR"
    end
  end

  context "with a value parameter and the :ctx keyword" do
    let(:callable) { ->(cents, ctx:) { "#{cents / 100.0} #{ctx[:currency]}" } }

    it "formats the value with the context" do
      expect(formatted).to eq "12.34 EUR"
    end
  end
end
