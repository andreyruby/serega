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

    it "raises error when unknown options are present" do
      opts[:delegate] = {to: :user, unknown: true}
      expect { check }.to raise_error Serega::SeregaError, /unknown/
    end
  end

  context "with hash access sub-options" do
    let(:opts) { {delegate: {to: :user, to_hash_access: true, hash_access: :string}} }

    before do
      allow(Serega::SeregaValidations::Utils::CheckHashAccessValue).to receive(:call)
    end

    it "checks both sub-options" do
      check

      expect(Serega::SeregaValidations::Utils::CheckHashAccessValue)
        .to have_received(:call).with(opts[:delegate], :to_hash_access)
      expect(Serega::SeregaValidations::Utils::CheckHashAccessValue)
        .to have_received(:call).with(opts[:delegate], :hash_access)
    end
  end
end
