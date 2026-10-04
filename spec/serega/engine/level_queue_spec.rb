# frozen_string_literal: true

RSpec.describe Serega::SeregaEngine::LevelQueue do
  subject(:queue) { described_class.new(mode: :struct) }

  let(:serializer) { double }

  describe "#add" do
    it "returns a new level with the objects" do
      level = queue.add(serializer, [1, 2])

      expect(level).to be_a Serega::SeregaEngine::Level
      expect(level.objects).to eq [1, 2]
    end
  end

  describe "#run" do
    let(:steps) { [] }
    let(:level1) { queue.add(serializer, [1]) }
    let(:level2) { instance_double(Serega::SeregaEngine::Level) }

    before do
      allow(level1).to receive(:discover) do
        queue.instance_variable_get(:@levels) << level2
        steps << :discover1
      end
      allow(level2).to receive(:discover) { steps << :discover2 }
      allow(level1).to receive(:build) { steps << :build1 }
      allow(level2).to receive(:build) { steps << :build2 }
    end

    it "discovers levels top-down, including added levels, and builds them bottom-up" do
      queue.run

      expect(steps).to eq %i[discover1 discover2 build2 build1]
    end
  end
end
