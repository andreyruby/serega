# frozen_string_literal: true

RSpec.describe Serega::SeregaEngine::Level do
  subject(:level) { described_class.new(serializer) }

  let(:serializer) { double(context: context) }
  let(:context) { "CONTEXT" }
  let(:batch_loader) { double(load: batch_data) }
  let(:batch_data) { {1 => "John", 2 => "Jane"} }

  describe "#add" do
    it "accumulates chunks of objects and returns a fresh container per object" do
      first = level.add([1, 2])
      second = level.add([3])

      expect(level.objects).to eq [1, 2, 3]
      expect(first).to eq [{}, {}]
      expect(second).to eq [{}]
      expect(level.containers).to eq(first + second)
    end

    it "returns the same container instances it stores, to be filled in place" do
      containers = level.add([1, 2])
      containers[0][:a] = 1
      expect(level.containers[0]).to equal containers[0]
    end
  end

  describe "#process" do
    it "asks its serializer to resolve the level" do
      allow(serializer).to receive(:process)
      level.process
      expect(serializer).to have_received(:process).with(level)
    end
  end

  describe "#load" do
    before { level.add([1, 2]) }

    it "loads values for the gathered objects and the serializer context" do
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
