# frozen_string_literal: true

RSpec.describe Serega::SeregaPlanPoint do
  let(:base) { Class.new(Serega) }

  def point_for(serializer, name)
    serializer::SeregaPlan.new(nil, {}).points.find { |point| point.name == name }
  end

  describe "#preloads" do
    it "returns the attribute's declared preloads" do
      serializer = Class.new(base) { attribute :author, preload: :author }.freeze
      expect(point_for(serializer, :author).preloads).to eq :author
    end

    it "is nil when the attribute declares no preloads" do
      serializer = Class.new(base) { attribute :name }.freeze
      expect(point_for(serializer, :name).preloads).to be_nil
    end
  end

  describe "#conditional?" do
    subject(:conditional) { point_for(serializer, :email).conditional? }

    let(:serializer) do
      opts = attribute_opts
      Class.new(base) { attribute :email, **opts }.freeze
    end

    context "without conditions" do
      let(:attribute_opts) { {} }

      it "returns false" do
        expect(conditional).to be false
      end
    end

    %i[if unless if_value unless_value].each do |option|
      context "with the :#{option} condition" do
        let(:attribute_opts) { {option => :present?} }

        it "returns true" do
          expect(conditional).to be true
        end
      end
    end
  end
end
