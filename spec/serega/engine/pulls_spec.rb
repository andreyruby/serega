# frozen_string_literal: true

RSpec.describe Serega::SeregaEngine::Pulls do
  let(:ann) { double(name: "Ann") }
  let(:bob) { double(name: "Bob") }
  let(:many) { nil }
  let(:known_classes) { {}.compare_by_identity }

  describe ".append" do
    subject(:pull) { described_class.append(sources, relation_source, many, known_classes) }

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
