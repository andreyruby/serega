# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::Collection do
  it "returns true for Enumerable objects" do
    expect(described_class.call([])).to be true
    expect(described_class.call(Set.new)).to be true
    expect(described_class.call([].each)).to be true
  end

  it "returns false for non-Enumerable objects" do
    expect(described_class.call(nil)).to be false
    expect(described_class.call("string")).to be false
    expect(described_class.call(Object.new)).to be false
  end

  it "returns false for Hash objects" do
    expect(described_class.call({})).to be false
  end

  it "returns false for Struct objects" do
    point_struct = Struct.new(:x, :y)
    expect(described_class.call(point_struct.new(1, 2))).to be false
  end
end
