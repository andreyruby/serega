# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::EnumDeepDup do
  describe ".call" do
    it "makes deep dup of hash" do
      hash = {key1: {key11: {key111: :value111}}, key2: [{key22: {key222: :value222}}]}
      dup = described_class.call(hash)

      expect(hash).to eq dup

      expect(hash).not_to equal dup
      expect(hash[:key1]).not_to equal dup[:key1]
      expect(hash[:key1][:key11]).not_to equal dup[:key1][:key11]

      expect(hash[:key2]).not_to equal dup[:key2]
      expect(hash[:key2][0]).not_to equal dup[:key2][0]
      expect(hash[:key2][0][:key22]).not_to equal dup[:key2][0][:key22]
    end

    it "duplicates strings" do
      string = +"value"
      dup = described_class.call({key: [string]})

      expect(dup[:key][0]).to eq string
      expect(dup[:key][0]).not_to equal string
    end

    it "does not duplicates non-enumerable objects" do
      hash = {key1: Serega, key2: [-> {}]}
      dup = described_class.call(hash)

      expect(hash).to eq dup
      expect(hash[:key1]).to equal dup[:key1]
      expect(hash[:key2][0]).to equal dup[:key2][0]
    end
  end
end
