# frozen_string_literal: true

RSpec.describe Serega::SeregaResultCode::RelationPointCode do
  let(:point_code) { described_class.new(point, 1) }
  let(:point) { default_plan(serializer).points.first }

  let(:serializer) do
    post_serializer = Class.new(Serega) { attribute :title }
    Class.new(Serega) { attribute :posts, serializer: post_serializer, many: true }
  end

  describe "#variables" do
    it "returns the code that reads the relation values" do
      expect(point_code.variables).to eq ["relation_values_1 = relations[@points[1]]"]
    end
  end

  describe "#assign_value" do
    it "returns the code that assigns the relation value of the source" do
      expect(point_code.assign_value).to eq "value_1 = relation_values_1[source_index]"
    end
  end

  describe "#call_one?" do
    it "returns false" do
      expect(point_code.call_one?).to be false
    end
  end
end
