# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::EnumDeepFreeze do
  it "deeply freezes provided hash" do
    hash = {key1: {key11: {key111: :value111}}, key2: [{key22: {key222: :value222}}]}
    described_class.call(hash)

    expect(hash).to be_frozen
    expect(hash[:key1]).to be_frozen
    expect(hash[:key1][:key11]).to be_frozen

    expect(hash[:key2]).to be_frozen
    expect(hash[:key2][0]).to be_frozen
    expect(hash[:key2][0][:key22]).to be_frozen
  end

  it "replaces strings with frozen copies" do
    string = +"value"
    hash = described_class.call({key: [string]})

    expect(hash[:key][0]).to eq "value"
    expect(hash[:key][0]).to be_frozen
    expect(string).not_to be_frozen
  end

  it "does not freeze non-hash and non-array objects" do
    obj = Object.new
    described_class.call(obj)
    expect(obj).not_to be_frozen
  end
end
