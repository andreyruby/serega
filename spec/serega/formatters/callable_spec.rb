# frozen_string_literal: true

RSpec.describe Serega::SeregaFormatters::Callable do
  let(:formatter) { described_class.new(callable, allow_nil) }
  let(:allow_nil) { false }

  describe "#call" do
    subject(:formatted) { formatter.call(value, context) }

    let(:value) { 1234 }
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

    context "with a nil value" do
      let(:callable) { ->(cents) { cents.inspect } }
      let(:value) { nil }

      it "formats nil" do
        expect(formatted).to eq "nil"
      end
    end

    context "with a nil value and allow_nil: true" do
      let(:callable) { ->(cents) { cents.inspect } }
      let(:allow_nil) { true }
      let(:value) { nil }

      it "returns nil" do
        expect(formatted).to be_nil
      end
    end
  end

  describe "#code" do
    subject(:code) { formatter.code("source.balance", "FORMATTERS[:balance]", "FORMATTER_ARGS[:balance]") }

    context "with a value parameter" do
      let(:callable) { ->(cents) { cents / 100.0 } }

      it "returns the code that calls the formatter" do
        expect(code).to eq "FORMATTERS[:balance].call(source.balance)"
      end
    end

    context "with a value parameter and allow_nil: true" do
      let(:callable) { ->(cents) { cents / 100.0 } }
      let(:allow_nil) { true }

      it "returns the code that calls the formatter for a value that is not nil" do
        expect(code).to eq "(value = source.balance).nil? ? nil : FORMATTERS[:balance].call(value)"
      end
    end

    context "with value and context parameters" do
      let(:callable) { ->(cents, context) { cents / context[:divider] } }

      it "returns nil" do
        expect(code).to be_nil
      end
    end
  end

  describe "#args" do
    let(:callable) { ->(cents) { cents } }

    it "returns nil" do
      expect(formatter.args).to be_nil
    end
  end
end
