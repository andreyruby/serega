# frozen_string_literal: true

RSpec.describe Serega::SeregaEngine::Level do
  subject(:level) { described_class.new(serializer, :struct) }

  let(:serializer) { double(context: context, discover: relations, build: results) }
  let(:context) { "CONTEXT" }
  let(:relations) { [["CHILD_LEVEL", [nil, nil]]] }
  let(:results) { %w[RESULT1 RESULT2] }

  describe "#add" do
    it "adds objects and returns the index of the first added object" do
      expect(level.add([1, 2])).to eq 0
      expect(level.add([3])).to eq 2

      expect(level.objects).to eq [1, 2, 3]
    end
  end

  describe "#discover" do
    it "asks its serializer to discover the level" do
      level.discover

      expect(serializer).to have_received(:discover).with(level)
    end
  end

  describe "#build" do
    it "builds results with the mode and the discovered relations" do
      level.discover
      level.build

      expect(serializer).to have_received(:build).with(level, :struct, relations)
      expect(level.results).to eq results
    end
  end

  describe "#fetch" do
    let(:batch_loader) { double(load: batch_data) }
    let(:batch_data) { {1 => "John", 2 => "Jane"} }

    before { level.add([1, 2]) }

    it "loads values for the objects and the serializer context" do
      expect(level.fetch(batch_loader)).to eq batch_data
      expect(batch_loader).to have_received(:load).with([1, 2], context)
    end

    it "loads the same loader only once" do
      level.fetch(batch_loader)
      level.fetch(batch_loader)

      expect(batch_loader).to have_received(:load).once
    end

    it "loads different loaders separately" do
      other_loader = double(load: {})
      level.fetch(batch_loader)
      level.fetch(other_loader)

      expect(batch_loader).to have_received(:load).once
      expect(other_loader).to have_received(:load).once
    end
  end
end
