# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptHashAccess do
  subject(:check) { described_class.call(opts) }

  let(:opts) { {} }

  it "allows no :hash_access option" do
    opts[:foo] = nil
    expect { check }.not_to raise_error
  end

  it "allows boolean values" do
    expect { described_class.call({hash_access: true}) }.not_to raise_error
    expect { described_class.call({hash_access: false}) }.not_to raise_error
  end

  it "allows Symbol modes" do
    expect { described_class.call({hash_access: :symbol}) }.not_to raise_error
    expect { described_class.call({hash_access: :string}) }.not_to raise_error
    expect { described_class.call({hash_access: :auto}) }.not_to raise_error
  end

  it "raises error on unknown Symbol mode" do
    opts[:hash_access] = :fetch
    expect { check }.to raise_error Serega::SeregaError,
      "Invalid :hash_access mode :fetch. Allowed modes: :symbol, :string, :auto"
  end

  context "when :hash_access is a Hash" do
    it "allows :mode and :allow_nil keys" do
      opts[:hash_access] = {mode: :string, allow_nil: true}
      expect { check }.not_to raise_error
    end

    it "allows partial keys" do
      expect { described_class.call({hash_access: {mode: :string}}) }.not_to raise_error
      expect { described_class.call({hash_access: {allow_nil: true}}) }.not_to raise_error
      expect { described_class.call({hash_access: {}}) }.not_to raise_error
    end

    it "checks allowed keys" do
      opts[:hash_access] = {mode: :string, foo: nil}
      expect { check }.to raise_error Serega::SeregaError, /foo/
    end

    it "raises error on unknown :mode" do
      opts[:hash_access] = {mode: :fetch}
      expect { check }.to raise_error Serega::SeregaError,
        "Invalid :hash_access mode :fetch. Allowed modes: :symbol, :string, :auto"
    end

    it "raises error on non-boolean :allow_nil" do
      opts[:hash_access] = {allow_nil: nil}
      expect { check }.to raise_error Serega::SeregaError,
        "Invalid :hash_access option :allow_nil => nil. Must be a Boolean"
    end
  end

  it "raises error on other value types" do
    opts[:hash_access] = "symbol"
    expect { check }.to raise_error Serega::SeregaError,
      "Invalid option :hash_access => \"symbol\"." \
      " It must be a Boolean, a Symbol mode (:symbol, :string, :auto)" \
      " or a Hash with :mode and :allow_nil keys"
  end

  context "with other options" do
    it "prohibits to use with :const opt" do
      opts.merge!(hash_access: true, const: 1)
      expect { check }.to raise_error Serega::SeregaError, "Option :hash_access can not be used together with option :const"
    end

    it "prohibits to use with :value opt" do
      opts.merge!(hash_access: true, value: proc {})
      expect { check }.to raise_error Serega::SeregaError, "Option :hash_access can not be used together with option :value"
    end

    it "prohibits to use with :batch opt" do
      opts.merge!(hash_access: true, batch: proc {})
      expect { check }.to raise_error Serega::SeregaError, "Option :hash_access can not be used together with option :batch"
    end

    it "prohibits to use with :delegate opt" do
      opts.merge!(hash_access: true, delegate: {to: :address})
      expect { check }.to raise_error Serega::SeregaError,
        "Option :hash_access can not be used together with option :delegate." \
        " Use the delegate :hash_access (intermediate step) and" \
        " :method_hash_access (final step) sub-options instead"
    end

    it "allows `hash_access: false` together with any option" do
      opts.merge!(hash_access: false, const: 1)
      expect { check }.not_to raise_error
    end
  end
end
