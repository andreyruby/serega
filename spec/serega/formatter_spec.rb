# frozen_string_literal: true

RSpec.describe Serega::SeregaFormatter do
  let(:formatter) { described_class.new(callable) }

  describe "#call" do
    subject(:formatted) { formatter.call(1234, context) }

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

  describe "#code" do
    subject(:code) { formatter.code("source.balance", "FORMATTERS[:balance]") }

    context "with a value parameter" do
      let(:callable) { ->(cents) { cents / 100.0 } }

      it "returns the code that calls the formatter" do
        expect(code).to eq "FORMATTERS[:balance].call(source.balance)"
      end
    end

    context "with value and context parameters" do
      let(:callable) { ->(cents, context) { cents / context[:divider] } }

      it "returns nil" do
        expect(code).to be_nil
      end
    end
  end
end
