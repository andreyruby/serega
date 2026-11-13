# frozen_string_literal: true

RSpec.describe Serega::SeregaResultCode do
  subject(:result_code) { described_class.new(mode, plan.points, compact: compact) }

  let(:mode) { :hash }
  let(:compact) { false }
  let(:serializer) { Class.new(Serega) { attribute :name } }
  let(:plan) { default_plan(serializer) }

  describe "#to_s" do
    it "returns the code of the call method" do
      expect(result_code.to_s).to start_with("def call(sources, context, batches, relations)")
    end

    it "returns no collect method" do
      expect(result_code.to_s).not_to include "def collect"
    end

    context "with relations" do
      let(:serializer) do
        post_serializer = Class.new(Serega) { attribute :title }
        Class.new(Serega) do
          attribute :posts, serializer: post_serializer, many: true
          attribute :pinned_post, serializer: post_serializer, many: false
        end
      end

      it "returns the collect method that gives the child sources and the pulls of each relation" do
        expect(result_code.to_s)
          .to include("def collect(sources, context, batches)\n  size = sources.size\n")
          .and include("  [child_sources_0, pulls_0, child_sources_1, pulls_1]\nend")
      end
    end

    context "with compact" do
      let(:compact) { true }

      it "returns the code that adds each value that is not nil to an empty Hash" do
        expect(result_code.to_s).to include <<~RUBY
          serialized_hash = {}
              serialized_hash[:name] = value_0 unless value_0.nil?
              serialized[source_index] = serialized_hash
        RUBY
      end
    end
  end

  describe "#mode" do
    it "returns the serialization mode" do
      expect(result_code.mode).to eq :hash
    end
  end
end
