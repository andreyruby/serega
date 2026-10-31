# frozen_string_literal: true

RSpec.describe Serega::SeregaFormatters::Method do
  let(:formatter) { described_class.new(use, allow_nil) }
  let(:allow_nil) { false }

  describe "#call" do
    subject(:formatted) { formatter.call(value, {}) }

    let(:value) { 1234 }

    context "with a method name" do
      let(:use) { :to_s }

      it "calls the method on the value" do
        expect(formatted).to eq "1234"
      end
    end

    context "with a method name and arguments" do
      let(:use) { [:fdiv, 100] }

      it "calls the method with the arguments" do
        expect(formatted).to eq 12.34
      end
    end

    context "with a nil value" do
      let(:use) { :inspect }
      let(:value) { nil }

      it "calls the method on nil" do
        expect(formatted).to eq "nil"
      end
    end

    context "with a nil value and allow_nil: true" do
      let(:use) { :inspect }
      let(:allow_nil) { true }
      let(:value) { nil }

      it "returns nil" do
        expect(formatted).to be_nil
      end
    end
  end

  describe "#code" do
    subject(:code) { formatter.code("source.balance", "FORMATTERS[:balance]", "FORMATTER_ARGS[:balance]") }

    context "with a method name" do
      let(:use) { :to_s }

      it "returns the code that calls the method" do
        expect(code).to eq "(source.balance).to_s"
      end
    end

    context "with a method name and literal arguments" do
      let(:use) { [:format, "%.2f", 1, 1.5, :up, true, false, nil] }

      it "returns the code that calls the method with the arguments" do
        expect(code).to eq '(source.balance).format("%.2f".freeze, 1, 1.5, :up, true, false, nil)'
      end
    end

    context "with a method name and allow_nil: true" do
      let(:use) { [:round, 2] }
      let(:allow_nil) { true }

      it "returns the code that calls the method for a value that is not nil" do
        expect(code).to eq "(source.balance)&.round(2)"
      end
    end

    context "with a method name and an argument that is not a literal" do
      let(:use) { [:round, Float::INFINITY] }

      it "returns the code that reads the argument from the arguments" do
        expect(code).to eq "(source.balance).round(FORMATTER_ARGS[:balance][0])"
      end
    end

    context "with a method name, a literal and an object argument" do
      let(:use) { [:round, 2, Rational(1, 2)] }

      it "returns the code with the literal and the argument read from the arguments" do
        expect(code).to eq "(source.balance).round(2, FORMATTER_ARGS[:balance][1])"
      end
    end

    context "with an operator method name" do
      let(:use) { [:+, 1] }

      it "returns the code that sends the method" do
        expect(code).to eq "(source.balance).public_send(:+, 1)"
      end
    end

    context "with an operator method name and allow_nil: true" do
      let(:use) { [:*, Rational(1, 2)] }
      let(:allow_nil) { true }

      it "returns the code that sends the method for a value that is not nil" do
        expect(code).to eq "(source.balance)&.public_send(:*, FORMATTER_ARGS[:balance][0])"
      end
    end
  end

  describe "#callable" do
    let(:use) { :to_s }

    it "returns nil" do
      expect(formatter.callable).to be_nil
    end
  end
end
