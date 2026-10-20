# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::CollectionDetector do
  subject(:collection) { described_class.call(object, known_classes) }

  let(:known_classes) { {}.compare_by_identity }
  let(:object) { Set.new }

  it "returns true for an Enumerable object" do
    expect(collection).to be true
  end

  it "remembers the answer for the class of the object" do
    collection

    expect(known_classes.to_a).to eq [[Set, true]]
  end

  context "with an Array" do
    let(:object) { [] }

    it "returns true without remembering the class" do
      expect(collection).to be true
      expect(known_classes).to be_empty
    end
  end

  context "with an Enumerator" do
    let(:object) { [].each }

    it "returns true" do
      expect(collection).to be true
    end
  end

  context "with an object that is not Enumerable" do
    let(:object) { Object.new }

    it "returns false and remembers it for the class" do
      expect(collection).to be false
      expect(known_classes.to_a).to eq [[Object, false]]
    end
  end

  context "with nil" do
    let(:object) { nil }

    it "returns false" do
      expect(collection).to be false
    end
  end

  context "with a Hash" do
    let(:object) { {} }

    it "returns false" do
      expect(collection).to be false
    end
  end

  context "with a Struct" do
    let(:object) { Struct.new(:x, :y).new(1, 2) }

    it "returns false" do
      expect(collection).to be false
    end
  end

  context "with a class that has a remembered answer" do
    let(:object) { "Heisenberg" }
    let(:known_classes) { {String => true}.compare_by_identity }

    it "returns the remembered answer" do
      expect(collection).to be true
    end
  end

  context "when the known classes are full" do
    let(:object) { Object.new }
    let(:full_classes) { [String, Integer, Float, Symbol, Range, Regexp, Time, Proc] }
    let(:known_classes) { full_classes.to_h { |known_class| [known_class, false] }.compare_by_identity }

    it "returns the answer without remembering the class" do
      expect(collection).to be false
      expect(known_classes.keys).to eq full_classes
    end
  end
end
