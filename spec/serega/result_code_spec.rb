# frozen_string_literal: true

RSpec.describe Serega::SeregaResultCode do
  subject(:result_code) { described_class.new(mode, plan.points) }

  let(:mode) { :hash }
  let(:serializer) { Class.new(Serega) { attribute :name } }
  let(:plan) { default_plan(serializer) }

  describe "#to_s" do
    it "returns the code of the call method" do
      expect(result_code.to_s).to start_with("def call(sources, context, batches, relations)")
    end
  end

  describe "#mode" do
    it "returns the serialization mode" do
      expect(result_code.mode).to eq :hash
    end
  end
end
