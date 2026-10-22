# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::DeepMerge do
  subject(:merge) { described_class.call(hash, other) }

  let(:hash) { {data: 1, meta: {paging: {page: 1}, version: "1"}} }
  let(:other) { {meta: {paging: {total: 10}, version: "2"}} }

  it "merges nested hashes into the hash" do
    merge

    expect(hash).to eq(data: 1, meta: {paging: {page: 1, total: 10}, version: "2"})
  end

  it "does not change the other hash" do
    merge

    expect(other).to eq(meta: {paging: {total: 10}, version: "2"})
  end

  context "when a Hash meets another value" do
    let(:other) { {meta: "none"} }

    it "takes the other value" do
      merge

      expect(hash).to eq(data: 1, meta: "none")
    end
  end
end
