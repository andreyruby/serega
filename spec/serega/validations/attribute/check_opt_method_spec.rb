# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptMethod do
  subject(:check) { described_class.call(opts) }

  let(:opts) { {} }

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
end
