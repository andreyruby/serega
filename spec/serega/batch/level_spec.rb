# frozen_string_literal: true

RSpec.describe Serega::SeregaBatch::Level do
  subject(:level) { described_class.new(context) }

  let(:context) { "CONTEXT" }
  let(:batch_loader) { double(load: batch_data) }
  let(:batch_data) { {1 => "John", 2 => "Jane"} }

  describe "#add_objects" do
    it "accumulates chunks of objects" do
      level.add_objects([1, 2])
      level.add_objects([3])
      expect(level.objects).to eq [1, 2, 3]
    end
  end

  describe "#load" do
    before { level.add_objects([1, 2]) }

    it "loads values for gathered objects and context" do
      expect(level.load(batch_loader)).to eq batch_data
      expect(batch_loader).to have_received(:load).with([1, 2], context)
    end

    it "loads the same loader only once" do
      level.load(batch_loader)
      level.load(batch_loader)
      expect(batch_loader).to have_received(:load).once
    end

    it "loads different loaders separately" do
      other_loader = double(load: {})
      level.load(batch_loader)
      level.load(other_loader)
      expect(batch_loader).to have_received(:load).once
      expect(other_loader).to have_received(:load).once
    end

    it "freezes the gathered objects" do
      level.load(batch_loader)
      expect(level.objects).to be_frozen
    end

    it "rejects adding objects once a batch has loaded" do
      level.load(batch_loader)
      expect { level.add_objects([3]) }.to raise_error(FrozenError)
    end
  end
end
