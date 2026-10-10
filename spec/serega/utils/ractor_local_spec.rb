# frozen_string_literal: true

require "support/ractors"

RSpec.describe Serega::SeregaUtils::RactorLocal, if: defined?(Ractor) do
  let(:owner) { Class.new }

  it "stores the block result once" do
    first = described_class.fetch(owner, :plans) { [] }

    expect(described_class.fetch(owner, :plans) { [] }).to be first
  end

  it "keeps the values of each owner and key apart" do
    plans = described_class.fetch(owner, :plans) { [:plans] }

    expect(described_class.fetch(owner, :classes) { [:classes] }).to eq [:classes]
    expect(described_class.fetch(Class.new, :plans) { [:other] }).to eq [:other]
    expect(described_class.fetch(owner, :plans) { [] }).to be plans
  end

  it "keeps the values of each Ractor apart" do
    described_class.fetch(owner, :plans) { :main }

    value = run_in_ractor(described_class, owner) { |ractor_local, owner| ractor_local.fetch(owner, :plans) { :other } }

    expect(value).to eq :other
  end
end
