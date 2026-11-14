# frozen_string_literal: true

RSpec.describe Serega::SeregaResultCode::PointCode do
  let(:point_code) { described_class.new(point, 1) }
  let(:point) { default_plan(serializer).points.first }
  let(:serializer) { Class.new(Serega) { attribute :name } }

  describe "#hash_pair" do
    it "returns the pair of the name and the value" do
      expect(point_code.hash_pair).to eq ":name => value_1"
    end

    context "with a String key" do
      let(:serializer) do
        Class.new(Serega) do
          config.key_transform = ->(name) { name.to_s }
          attribute :name
        end
      end

      it "returns the pair of the String key and the value" do
        expect(point_code.hash_pair).to eq '-"name" => value_1'
      end
    end
  end

  describe "#hash_assign" do
    subject(:code) { point_code.hash_assign(compact) }

    let(:compact) { false }

    it "returns the code that adds the value" do
      expect(code).to eq "serialized_hash[:name] = value_1"
    end

    context "with a String key" do
      let(:serializer) do
        Class.new(Serega) do
          config.key_transform = ->(name) { name.to_s }
          attribute :name
        end
      end

      it "returns the code that adds the value by the String key" do
        expect(code).to eq 'serialized_hash[-"name"] = value_1'
      end
    end

    context "with a conditional point" do
      let(:serializer) { Class.new(Serega) { attribute :name, if: :active? } }

      it "returns the code that adds a value that is not skipped" do
        expect(code).to eq "serialized_hash[:name] = value_1 unless Serega::SeregaEngine::SKIP.equal?(value_1)"
      end
    end

    context "with compact" do
      let(:compact) { true }

      it "returns the code that adds a value that is not nil" do
        expect(code).to eq "serialized_hash[:name] = value_1 unless value_1.nil?"
      end
    end

    context "with compact and a conditional point" do
      let(:serializer) { Class.new(Serega) { attribute :name, if: :active? } }
      let(:compact) { true }

      it "returns the code that adds a value that is neither nil nor skipped" do
        expect(code)
          .to eq "serialized_hash[:name] = value_1 unless value_1.nil? || Serega::SeregaEngine::SKIP.equal?(value_1)"
      end
    end
  end

  describe "#argument" do
    subject(:code) { point_code.argument }

    it "returns the value" do
      expect(code).to eq "value_1"
    end

    context "with a conditional point" do
      let(:serializer) { Class.new(Serega) { attribute :name, if: :active? } }

      it "returns nil for a skipped value" do
        expect(code).to eq "(Serega::SeregaEngine::SKIP.equal?(value_1) ? nil : value_1)"
      end
    end
  end
end
