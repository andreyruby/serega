# frozen_string_literal: true

RSpec.describe Serega::SeregaFormatter do
  let(:formatter) { described_class.new(declaration) }

  describe "#call" do
    subject(:formatted) { formatter.call(value, context) }

    let(:value) { 1234 }
    let(:context) { {currency: "EUR"} }

    context "with a value parameter" do
      let(:declaration) { ->(cents) { cents / 100.0 } }

      it "formats the value" do
        expect(formatted).to eq 12.34
      end
    end

    context "with value and context parameters" do
      let(:declaration) { ->(cents, context) { "#{cents / 100.0} #{context[:currency]}" } }

      it "formats the value with the context" do
        expect(formatted).to eq "12.34 EUR"
      end
    end

    context "with a value parameter and the :ctx keyword" do
      let(:declaration) { ->(cents, ctx:) { "#{cents / 100.0} #{ctx[:currency]}" } }

      it "formats the value with the context" do
        expect(formatted).to eq "12.34 EUR"
      end
    end

    context "with a method name" do
      let(:declaration) { :to_s }

      it "calls the method on the value" do
        expect(formatted).to eq "1234"
      end
    end

    context "with a method name and arguments" do
      let(:declaration) { [:fdiv, 100] }

      it "calls the method with the arguments" do
        expect(formatted).to eq 12.34
      end
    end

    context "with a nil value" do
      let(:declaration) { ->(cents) { cents.inspect } }
      let(:value) { nil }

      it "formats nil" do
        expect(formatted).to eq "nil"
      end
    end

    context "with a nil value and allow_nil: true" do
      let(:declaration) { {use: ->(cents) { cents.inspect }, allow_nil: true} }
      let(:value) { nil }

      it "returns nil" do
        expect(formatted).to be_nil
      end
    end
  end

  describe "#code" do
    subject(:code) { formatter.code("source.balance", "FORMATTERS[:balance]", "FORMATTER_ARGS[:balance]") }

    context "with a value parameter" do
      let(:declaration) { ->(cents) { cents / 100.0 } }

      it "returns the code that calls the formatter" do
        expect(code).to eq "FORMATTERS[:balance].call(source.balance)"
      end
    end

    context "with a value parameter and allow_nil: true" do
      let(:declaration) { {use: ->(cents) { cents / 100.0 }, allow_nil: true} }

      it "returns the code that calls the formatter for a value that is not nil" do
        expect(code).to eq "(value = source.balance).nil? ? nil : FORMATTERS[:balance].call(value)"
      end
    end

    context "with value and context parameters" do
      let(:declaration) { ->(cents, context) { cents / context[:divider] } }

      it "returns nil" do
        expect(code).to be_nil
      end
    end

    context "with a method name" do
      let(:declaration) { :to_s }

      it "returns the code that calls the method" do
        expect(code).to eq "(source.balance).to_s"
      end
    end

    context "with a method name and literal arguments" do
      let(:declaration) { [:format, "%.2f", 1, 1.5, :up, true, false, nil] }

      it "returns the code that calls the method with the arguments" do
        expect(code).to eq '(source.balance).format("%.2f".freeze, 1, 1.5, :up, true, false, nil)'
      end
    end

    context "with a method name and allow_nil: true" do
      let(:declaration) { {use: [:round, 2], allow_nil: true} }

      it "returns the code that calls the method for a value that is not nil" do
        expect(code).to eq "(source.balance)&.round(2)"
      end
    end

    context "with a method name and an argument that is not a literal" do
      let(:declaration) { [:round, Float::INFINITY] }

      it "returns the code that reads the argument from the arguments" do
        expect(code).to eq "(source.balance).round(FORMATTER_ARGS[:balance][0])"
      end
    end

    context "with a method name, a literal and an object argument" do
      let(:declaration) { [:round, 2, Rational(1, 2)] }

      it "returns the code with the literal and the argument read from the arguments" do
        expect(code).to eq "(source.balance).round(2, FORMATTER_ARGS[:balance][1])"
      end
    end

    context "with an operator method name" do
      let(:declaration) { [:+, 1] }

      it "returns the code that sends the method" do
        expect(code).to eq "(source.balance).public_send(:+, 1)"
      end
    end

    context "with an operator method name and allow_nil: true" do
      let(:declaration) { {use: [:*, Rational(1, 2)], allow_nil: true} }

      it "returns the code that sends the method for a value that is not nil" do
        expect(code).to eq "(source.balance)&.public_send(:*, FORMATTER_ARGS[:balance][0])"
      end
    end
  end
end
