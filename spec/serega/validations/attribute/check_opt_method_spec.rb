# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptMethod do
  subject(:check) { described_class.call(opts, block) }

  let(:opts) { {} }
  let(:block) { nil }

  it "allows no :method option" do
    opts[:foo] = nil
    expect { check }.not_to raise_error
  end

  it "allows :method option with symbol" do
    opts[:method] = :name
    expect { check }.not_to raise_error
  end

  it "allows :method option with string" do
    opts[:method] = "name"
    expect { check }.not_to raise_error
  end

  it "raises error when :method is not a symbol or string" do
    opts[:method] = 123
    expect { check }.to raise_error Serega::SeregaError, "Invalid option :method => 123. Must be a String or a Symbol"
  end

  context "with other options" do
    it "prohibits to use with :const opt" do
      opts.merge!(method: :name, const: 1)
      expect { check }.to raise_error Serega::SeregaError, "Option :method can not be used together with option :const"
    end

    it "prohibits to use with :value opt" do
      opts.merge!(method: :name, value: proc {})
      expect { check }.to raise_error Serega::SeregaError, "Option :method can not be used together with option :value"
    end

    it "prohibits to use with :batch opt" do
      opts.merge!(method: :name, batch: :test_loader)
      expect { check }.to raise_error Serega::SeregaError, "Option :method can not be used together with option :batch"
    end

    it "prohibits to use with block" do
      opts[:method] = :name
      expect { described_class.call(opts, proc {}) }.to raise_error Serega::SeregaError, "Option :method can not be used together with block"
    end
  end
end
