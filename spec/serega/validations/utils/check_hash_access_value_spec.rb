# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Utils::CheckHashAccessValue do
  subject(:check) { described_class.call(opts, :to_hash_access) }

  let(:opts) { {to_hash_access: value} }
  let(:value) { true }

  it "does not raise" do
    expect { check }.not_to raise_error
  end

  context "without the option" do
    let(:opts) { {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with false" do
    let(:value) { false }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a mode" do
    let(:value) { :string }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with an unknown mode" do
    let(:value) { :fetch }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, "Invalid :hash_access mode :fetch. Allowed modes: :symbol, :string"
    end
  end

  context "with a Hash with :mode and :allow_missing_key" do
    let(:value) { {mode: :symbol, allow_missing_key: true} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with an empty Hash" do
    let(:value) { {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a Hash with an unknown mode" do
    let(:value) { {mode: :fetch} }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, "Invalid :hash_access mode :fetch. Allowed modes: :symbol, :string"
    end
  end

  context "with a Hash with an unknown key" do
    let(:value) { {mode: :symbol, foo: nil} }

    it "raises an error" do
      expect { check }
        .to raise_error Serega::SeregaError, "Invalid to_hash_access option :foo. Allowed options are: :allow_missing_key, :mode"
    end
  end

  context "with a Hash with a non-boolean :allow_missing_key" do
    let(:value) { {allow_missing_key: nil} }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, "Invalid option :allow_missing_key => nil. Must have a boolean value"
    end
  end

  context "with a String" do
    let(:value) { "symbol" }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError,
        "Invalid option :to_hash_access => \"symbol\"." \
        " It must be a Boolean, a Symbol mode (:symbol, :string)" \
        " or a Hash with :mode and :allow_missing_key keys"
    end
  end
end
