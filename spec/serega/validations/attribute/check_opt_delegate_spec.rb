# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptDelegate do
  subject(:check) { described_class.call(opts) }

  let(:opts) { {} }

  it "allows no :delegate option" do
    opts[:foo] = nil
    expect { check }.not_to raise_error
  end

  context "when :delegate is a hash" do
    it "requires :to option" do
      opts[:delegate] = {}
      expect { check }.to raise_error Serega::SeregaError, "Option :delegate must have a :to option"
    end

    it "allows :to option with symbol" do
      opts[:delegate] = {to: :user}
      expect { check }.not_to raise_error
    end

    it "allows :to option with string" do
      opts[:delegate] = {to: "user"}
      expect { check }.not_to raise_error
    end

    it "raises error when :to is not a symbol or string" do
      opts[:delegate] = {to: 123}
      expect { check }.to raise_error Serega::SeregaError, "Invalid option :to => 123. Must be a String or a Symbol"
    end

    it "allows :method option with symbol" do
      opts[:delegate] = {to: :user, method: :name}
      expect { check }.not_to raise_error
    end

    it "allows :method option with string" do
      opts[:delegate] = {to: :user, method: "name"}
      expect { check }.not_to raise_error
    end

    it "raises error when :method is not a symbol or string" do
      opts[:delegate] = {to: :user, method: 123}
      expect { check }.to raise_error Serega::SeregaError, "Invalid option :method => 123. Must be a String or a Symbol"
    end

    it "allows :allow_nil option with boolean" do
      opts[:delegate] = {to: :user, allow_nil: true}
      expect { check }.not_to raise_error
    end

    it "raises error when :allow_nil is not a boolean" do
      opts[:delegate] = {to: :user, allow_nil: 123}
      expect { check }.to raise_error Serega::SeregaError, "Invalid option :allow_nil => 123. Must have a boolean value"
    end

    it "allows :to_hash_access option with boolean, Symbol mode or Hash form" do
      expect { described_class.call({delegate: {to: :user, to_hash_access: true}}) }.not_to raise_error
      expect { described_class.call({delegate: {to: :user, to_hash_access: false}}) }.not_to raise_error
      expect { described_class.call({delegate: {to: :user, to_hash_access: :symbol}}) }.not_to raise_error
      expect { described_class.call({delegate: {to: :user, to_hash_access: :string}}) }.not_to raise_error
      expect {
        described_class.call({delegate: {to: :user, to_hash_access: {mode: :symbol, allow_missing_key: true}}})
      }.not_to raise_error
      expect { described_class.call({delegate: {to: :user, to_hash_access: {allow_missing_key: true}}}) }.not_to raise_error
    end

    it "raises error when :to_hash_access mode is unknown" do
      opts[:delegate] = {to: :user, to_hash_access: :fetch}
      expect { check }.to raise_error Serega::SeregaError,
        "Invalid :hash_access mode :fetch. Allowed modes: :symbol, :string"
    end

    it "raises error when :to_hash_access Hash form has unknown keys" do
      opts[:delegate] = {to: :user, to_hash_access: {mode: :symbol, foo: nil}}
      expect { check }.to raise_error Serega::SeregaError, /foo/
    end

    it "raises error when :to_hash_access :allow_missing_key is not a boolean" do
      opts[:delegate] = {to: :user, to_hash_access: {allow_missing_key: nil}}
      expect { check }.to raise_error Serega::SeregaError,
        "Invalid option :allow_missing_key => nil. Must have a boolean value"
    end

    it "raises error when :to_hash_access has an invalid type" do
      value = "symbol"
      opts[:delegate] = {to: :user, to_hash_access: value}
      expect { check }.to raise_error Serega::SeregaError,
        "Invalid delegate option :to_hash_access => #{value.inspect}." \
        " It must be a Boolean, a Symbol mode (:symbol, :string)" \
        " or a Hash with :mode and :allow_missing_key keys"
    end

    it "allows :hash_access option with boolean, Symbol mode or Hash form" do
      expect { described_class.call({delegate: {to: :user, hash_access: true}}) }.not_to raise_error
      expect { described_class.call({delegate: {to: :user, hash_access: false}}) }.not_to raise_error
      expect { described_class.call({delegate: {to: :user, hash_access: :string}}) }.not_to raise_error
      expect {
        described_class.call({delegate: {to: :user, hash_access: {mode: :symbol, allow_missing_key: true}}})
      }.not_to raise_error
      expect {
        described_class.call({delegate: {to: :user, hash_access: {allow_missing_key: true}}})
      }.not_to raise_error
    end

    it "raises error when :hash_access mode is unknown" do
      opts[:delegate] = {to: :user, hash_access: {mode: :fetch}}
      expect { check }.to raise_error Serega::SeregaError,
        "Invalid :hash_access mode :fetch. Allowed modes: :symbol, :string"
    end

    it "raises error when :hash_access Hash form has unknown keys" do
      opts[:delegate] = {to: :user, hash_access: {mode: :symbol, foo: nil}}
      expect { check }.to raise_error Serega::SeregaError, /foo/
    end

    it "raises error when :hash_access :allow_missing_key is not a boolean" do
      opts[:delegate] = {to: :user, hash_access: {allow_missing_key: nil}}
      expect { check }.to raise_error Serega::SeregaError,
        "Invalid option :allow_missing_key => nil. Must have a boolean value"
    end

    it "raises error when :hash_access has an invalid type" do
      value = "symbol"
      opts[:delegate] = {to: :user, hash_access: value}
      expect { check }.to raise_error Serega::SeregaError,
        "Invalid delegate option :hash_access => #{value.inspect}." \
        " It must be a Boolean, a Symbol mode (:symbol, :string)" \
        " or a Hash with :mode and :allow_missing_key keys"
    end

    it "raises error when unknown options are present" do
      opts[:delegate] = {to: :user, unknown: true}
      expect { check }.to raise_error Serega::SeregaError, /unknown/
    end
  end

  context "with other options" do
    it "prohibits to use with :method opt" do
      opts.merge!(delegate: {to: :user}, method: :method)
      expect { check }.to raise_error Serega::SeregaError, "Option :delegate can not be used together with option :method"
    end

    it "prohibits to use with :const opt" do
      opts.merge!(delegate: {to: :user}, const: 1)
      expect { check }.to raise_error Serega::SeregaError, "Option :delegate can not be used together with option :const"
    end

    it "prohibits to use with :value opt" do
      opts.merge!(delegate: {to: :user}, value: proc {})
      expect { check }.to raise_error Serega::SeregaError, "Option :delegate can not be used together with option :value"
    end

    it "prohibits to use with :batch opt" do
      opts.merge!(delegate: {to: :user}, batch: :test_loader)
      expect { check }.to raise_error Serega::SeregaError, "Option :delegate can not be used together with option :batch"
    end
  end
end
