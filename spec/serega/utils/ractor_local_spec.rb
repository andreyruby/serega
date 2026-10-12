# frozen_string_literal: true

require "support/ractors"

RSpec.describe Serega::SeregaUtils::RactorLocal, if: defined?(Ractor) do
  let(:owner) { Class.new }
  let(:key) { described_class.key(owner, :plans) }

  describe ".key" do
    it "returns a Symbol per owner and name" do
      expect(key).to eq :"serega_plans_#{owner.object_id}"
      expect(described_class.key(owner, :classes)).not_to eq key
    end
  end

  describe ".fetch" do
    it "stores the block result once" do
      first = described_class.fetch(key) { [] }

      expect(described_class.fetch(key) { [] }).to be first
    end

    it "keeps the values of each Ractor apart" do
      described_class.fetch(key) { :main }

      value = run_in_ractor(described_class, key) { |ractor_local, key| ractor_local.fetch(key) { :other } }

      expect(value).to eq :other
    end
  end
end
