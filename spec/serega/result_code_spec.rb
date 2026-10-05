# frozen_string_literal: true

RSpec.describe Serega::SeregaResultCode do
  subject(:result_code) { serializer::SeregaResultCode.new(mode, plan.points) }

  let(:mode) { :hash }
  let(:serializer) { Class.new(Serega) { attribute :name } }
  let(:plan) { serializer::SeregaPlan.new(nil, {}) }

  describe ".serializer_class" do
    it "returns the serializer class" do
      expect(serializer::SeregaResultCode.serializer_class).to equal serializer
    end
  end

  describe "#to_s" do
    it "returns the code of the call method" do
      expect(result_code.to_s).to start_with("def call(objects, context, batches, relations)")
    end
  end

  describe "#mode" do
    it "returns the serialization mode" do
      expect(result_code.mode).to eq :hash
    end
  end
end
