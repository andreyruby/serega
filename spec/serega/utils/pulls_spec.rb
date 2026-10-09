# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::Pulls do
  let(:ann) { double(name: "Ann") }
  let(:bob) { double(name: "Bob") }
  let(:many) { nil }

  describe ".collect" do
    subject(:collected) { described_class.collect(relation_sources, many) }

    let(:relation_sources) { [[ann, bob], nil, ann] }

    it "returns the sources of all relation sources and the pull of each one" do
      expect(collected).to eq [[ann, bob, ann], [2, nil, described_class::SINGLE_SOURCE]]
    end

    context "when many is true and a relation source is not a collection" do
      let(:relation_sources) { [ann] }
      let(:many) { true }

      it "counts the relation source as a collection of one source" do
        expect(collected).to eq [[ann], [1]]
      end
    end

    context "when many is false and a relation source is a collection" do
      let(:relation_sources) { [[ann, bob]] }
      let(:many) { false }

      it "adds the collection as one source" do
        expect(collected).to eq [[[ann, bob]], [described_class::SINGLE_SOURCE]]
      end
    end
  end

  describe ".collect_conditional" do
    subject(:collected) { described_class.collect_conditional(relation_sources, many) }

    let(:relation_sources) { [[ann, bob], Serega::SeregaEngine::SKIP, ann] }

    it "keeps SKIP as the pull of a skipped relation source" do
      expect(collected).to eq [[ann, bob, ann], [2, Serega::SeregaEngine::SKIP, described_class::SINGLE_SOURCE]]
    end
  end

  describe ".append" do
    subject(:pull) { described_class.append(sources, relation_source, many) }

    let(:sources) { [ann] }
    let(:relation_source) { [bob, bob] }

    it "appends the sources of the relation source and returns their count" do
      expect(pull).to eq 2
      expect(sources).to eq [ann, bob, bob]
    end

    context "with nil" do
      let(:relation_source) { nil }

      it "appends no sources" do
        expect(pull).to be_nil
        expect(sources).to eq [ann]
      end
    end
  end

  describe ".take!" do
    subject(:relation_values) { described_class.take!(serialized, pulls) }

    let(:serialized) { [{name: "Ann"}, {name: "Bob"}, {name: "Cat"}] }
    let(:pulls) { [2, nil, Serega::SeregaEngine::SKIP, described_class::SINGLE_SOURCE] }

    it "takes the relation value of each pull from the front of the serialized objects" do
      expect(relation_values).to eq [[{name: "Ann"}, {name: "Bob"}], nil, Serega::SeregaEngine::SKIP, {name: "Cat"}]
      expect(serialized).to be_empty
    end
  end
end
