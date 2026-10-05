# frozen_string_literal: true

RSpec.describe Serega::SeregaEngine do
  describe Serega::SeregaEngine::LevelQueue do
    subject(:queue) { described_class.new(mode: mode) }

    let(:mode) { :hash }
    let(:plan) { Class.new(Serega) { attribute :name }::SeregaPlan.new(nil, {}) }
    let(:serializer) { double(plan: plan) }

    describe "#enqueue" do
      it "gathers objects into one level per plan and returns their containers" do
        first = queue.enqueue(serializer, [1, 2])
        second = queue.enqueue(serializer, [3])

        levels = queue.instance_variable_get(:@levels)
        expect(levels.size).to eq 1
        expect(levels.first.objects).to eq [1, 2, 3]
        expect(first).to eq [{}, {}]
        expect(second).to eq [{}]
        expect(levels.first.containers).to eq(first + second)
      end

      it "uses separate levels for different plans" do
        serializer2 = double(plan: Class.new(Serega)::SeregaPlan.new(nil, {}))
        queue.enqueue(serializer, [1])
        queue.enqueue(serializer2, [2])

        levels = queue.instance_variable_get(:@levels)
        expect(levels.size).to eq 2
        expect(levels.map(&:objects)).to eq [[1], [2]]
      end

      context "with the :struct mode" do
        let(:mode) { :struct }

        it "returns plan structs as containers" do
          expect(queue.enqueue(serializer, [1])).to eq [plan.result_builder(:struct).struct_class.new]
        end
      end
    end

    describe "#run" do
      it "processes every level, including ones enqueued while processing" do
        processed = []
        level1 = instance_double(Serega::SeregaEngine::Level)
        level2 = instance_double(Serega::SeregaEngine::Level)

        # processing level1 discovers (enqueues) level2
        allow(level1).to receive(:process) do
          queue.instance_variable_get(:@levels) << level2
          processed << :level1
        end
        allow(level2).to receive(:process) { processed << :level2 }

        queue.instance_variable_get(:@levels) << level1
        queue.run

        expect(processed).to eq %i[level1 level2]
      end
    end
  end
end
