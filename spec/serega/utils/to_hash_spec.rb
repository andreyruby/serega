# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::ToHash do
  subject(:result) { described_class.call(val) }

  context "with nil value" do
    let(:val) { nil }

    it "returns frozen hash" do
      expect(result).to eq({})
      expect(result).to be_frozen
    end
  end

  context "with false value" do
    let(:val) { false }

    it "returns frozen hash" do
      expect(result).to eq({})
      expect(result).to be_frozen
    end
  end

  context "with array value" do
    let(:val) { %w[foo bar] }

    it "returns hash with symbol keys and frozen empty hash values" do
      expect(result).to eq(foo: {}, bar: {})
      expect(result[:foo]).to be_frozen
      expect(result[:bar]).to be_frozen
    end
  end

  context "with empty array value" do
    let(:val) { [] }

    it "returns frozen empty Hash" do
      expect(result).to equal(Serega::FROZEN_EMPTY_HASH)
    end
  end

  context "with symbol value" do
    let(:val) { :foo }

    it "returns hash with frozen empty hash value" do
      expect(result).to eq(foo: {})
      expect(result[:foo]).to be_frozen
    end
  end

  context "with string value" do
    let(:val) { "foo" }

    it "returns hash with symbol key and frozen empty hash value" do
      expect(result).to eq(foo: {})
      expect(result[:foo]).to be_frozen
    end
  end

  context "with hash value" do
    let(:val) { {foo: :bar} }

    it "returns nested hash with frozen empty hash final value" do
      expect(result).to eq(foo: {bar: {}})
      expect(result[:foo][:bar]).to be_frozen
    end
  end

  context "with hash with string keys" do
    let(:val) { {"foo" => "bar"} }

    it "returns nested hash with symbol keys with frozen empty hash final value" do
      expect(result).to eq(foo: {bar: {}})
      expect(result[:foo][:bar]).to be_frozen
    end
  end

  context "with not supported type value" do
    let(:val) { 1 }

    it "raises error" do
      expect { result }.to raise_error Serega::SeregaError, "Can't convert Integer class object to hash"
    end
  end

  context "with true value" do
    let(:val) { true }

    it "returns frozen hash" do
      expect(result).to eq({})
      expect(result).to be_frozen
    end
  end

  context "with complex value test" do
    let(:val) { [:a, "b", {c: {"d" => [:e, "f"]}}] }

    it "returns nested hash with symbol keys" do
      expect(result).to eq(
        a: {},
        b: {},
        c: {d: {e: {}, f: {}}}
      )

      expect(result.dig(:a)).to be_frozen
      expect(result.dig(:b)).to be_frozen
      expect(result.dig(:c, :d, :e)).to be_frozen
      expect(result.dig(:c, :d, :f)).to be_frozen
    end
  end
end
