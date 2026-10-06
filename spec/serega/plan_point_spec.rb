# frozen_string_literal: true

RSpec.describe Serega::SeregaPlanPoint do
  let(:base) { Class.new(Serega) }

  def point_for(serializer, name)
    serializer::SeregaPlan.new(nil, {}).points.find { |point| point.name == name }
  end

  describe "#preloads" do
    it "returns the attribute's declared preloads" do
      serializer = Class.new(base) { attribute :author, preload: :author }
      expect(point_for(serializer, :author).preloads).to eq :author
    end

    it "is nil when the attribute declares no preloads" do
      serializer = Class.new(base) { attribute :name }
      expect(point_for(serializer, :name).preloads).to be_nil
    end
  end
end
