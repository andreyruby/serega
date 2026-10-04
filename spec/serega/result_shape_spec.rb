# frozen_string_literal: true

RSpec.describe Serega::SeregaResultShape do
  subject(:result_shape) { serializer::SeregaResultShape.new(mode, plan.points) }

  let(:serializer) do
    Class.new(Serega) do
      attribute :name
      attribute :email
    end
  end

  let(:plan) { serializer::SeregaPlan.new(nil, {}) }
  let(:mode) { :hash }

  describe ".data_class_for" do
    let(:described_class) { serializer::SeregaResultShape }

    it "returns a Data class with the given members" do
      data_class = described_class.data_class_for(%i[x y])

      expect(data_class).to be < Data
      expect(data_class.members).to eq %i[x y]
    end

    it "returns the same class for the same names" do
      expect(described_class.data_class_for(%i[a b])).to equal described_class.data_class_for(%i[a b])
    end

    it "returns different classes for different names" do
      expect(described_class.data_class_for(%i[a])).not_to equal described_class.data_class_for(%i[b])
    end

    it "keeps a separate cache for each serializer" do
      other_class = Class.new(Serega)::SeregaResultShape

      expect(described_class.data_class_for(%i[x])).not_to equal other_class.data_class_for(%i[x])
    end
  end

  describe ".struct_class_for" do
    let(:described_class) { serializer::SeregaResultShape }

    it "returns a Struct class with the given members" do
      struct_class = described_class.struct_class_for(%i[x y])

      expect(struct_class).to be < Struct
      expect(struct_class.members).to eq %i[x y]
    end

    it "returns the same class for the same names" do
      expect(described_class.struct_class_for(%i[a b])).to equal described_class.struct_class_for(%i[a b])
    end

    it "returns different classes for different names" do
      expect(described_class.struct_class_for(%i[a])).not_to equal described_class.struct_class_for(%i[b])
    end

    it "keeps a separate cache for each serializer" do
      other_class = Class.new(Serega)::SeregaResultShape

      expect(described_class.struct_class_for(%i[x])).not_to equal other_class.struct_class_for(%i[x])
    end
  end

  describe "#data_class" do
    it "returns a Data class with the plan attribute names as members" do
      expect(result_shape.data_class.members).to eq %i[name email]
    end

    it "returns the same Data class for result shapes with the same attributes" do
      other_shape = serializer::SeregaResultShape.new(mode, plan.points)

      expect(result_shape.data_class).to equal other_shape.data_class
    end
  end

  describe "#struct_class" do
    it "returns a Struct class with the plan attribute names as members" do
      expect(result_shape.struct_class.members).to eq %i[name email]
    end

    it "returns the same Struct class for result shapes with the same attributes" do
      other_shape = serializer::SeregaResultShape.new(mode, plan.points)

      expect(result_shape.struct_class).to equal other_shape.struct_class
    end
  end

  describe "#build_containers" do
    subject(:containers) { result_shape.build_containers(2) }

    it "returns separate empty hashes" do
      expect(containers).to eq [{}, {}]
      expect(containers[0]).not_to equal containers[1]
    end

    context "with the :data mode" do
      let(:mode) { :data }

      it "returns separate empty hashes" do
        expect(containers).to eq [{}, {}]
        expect(containers[0]).not_to equal containers[1]
      end
    end

    context "with the :struct mode" do
      let(:mode) { :struct }

      it "returns separate structs with nil members" do
        expect(containers.map(&:to_h)).to eq [{name: nil, email: nil}, {name: nil, email: nil}]
        expect(containers[0]).not_to equal containers[1]
      end
    end
  end
end
