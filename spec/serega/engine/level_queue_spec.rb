# frozen_string_literal: true

RSpec.describe Serega::SeregaEngine::LevelQueue do
  subject(:queue) { described_class.new(mode: :struct) }

  let(:serializer) { double(plan: "PLAN") }

  describe "#enqueue" do
    it "adds objects of one plan to one level and returns the index of the first added object" do
      expect(queue.enqueue(serializer, [1, 2])).to eq 0
      expect(queue.enqueue(serializer, [3])).to eq 2

      expect(queue.level(serializer).objects).to eq [1, 2, 3]
    end

    context "with objects of different plans" do
      let(:serializer2) { double(plan: "PLAN2") }

      it "adds them to separate levels" do
        queue.enqueue(serializer, [1])
        queue.enqueue(serializer2, [2])

        expect(queue.level(serializer).objects).to eq [1]
        expect(queue.level(serializer2).objects).to eq [2]
      end
    end
  end

  describe "#run" do
    let(:steps) { [] }
    let(:serializer2) { double(plan: "PLAN2") }
    let(:level1) { queue.level(serializer) }
    let(:level2) { queue.level(serializer2) }

    before do
      allow(level1).to receive(:discover) do
        level2
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
