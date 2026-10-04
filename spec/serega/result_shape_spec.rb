# frozen_string_literal: true

RSpec.describe Serega::SeregaResultShape do
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

  describe ".builder" do
    subject(:builder) { serializer::SeregaResultShape.builder(mode, plan.points) }

    let(:user) { Struct.new(:name, :email).new("Ann", "ann@example.com") }

    it "builds a hash per object" do
      expect(builder.call([user], {}, nil, nil)).to eq [{name: "Ann", email: "ann@example.com"}]
    end

    it "returns the same builder for the same attributes and mode" do
      expect(builder).to equal serializer::SeregaResultShape.builder(mode, serializer::SeregaPlan.new(nil, {}).points)
    end

    it "returns separate builders for different modes" do
      expect(builder).not_to equal serializer::SeregaResultShape.builder(:struct, plan.points)
    end

    context "with the :struct mode" do
      let(:mode) { :struct }

      it "builds a struct per object" do
        expect(builder.call([user], {}, nil, nil)).to eq [serializer::SeregaResultShape.struct_class_for(%i[name email]).new("Ann", "ann@example.com")]
      end
    end

    context "with the :data mode" do
      let(:mode) { :data }

      it "builds a Data object per object" do
        expect(builder.call([user], {}, nil, nil)).to eq [serializer::SeregaResultShape.data_class_for(%i[name email]).new("Ann", "ann@example.com")]
      end
    end

    context "with a relation" do
      let(:serializer) do
        Class.new(Serega) do
          attribute :name
          attribute :posts, serializer: Class.new(Serega)
        end
      end

      it "reads relation values from the built child results" do
        expect(builder.call([user], {}, nil, [[["POST"]]])).to eq [{name: "Ann", posts: ["POST"]}]
      end
    end

    context "with batch attributes" do
      let(:serializer) do
        Class.new(Serega) do
          attribute :name, batch: {use: proc { |ids| ids }, id: :email}
        end
      end

      it "reads values from the loaded batches" do
        expect(builder.call([user], {}, [{name: {"ann@example.com" => "Batch Ann"}}], nil)).to eq [{name: "Batch Ann"}]
      end
    end

    context "with a not plain method name" do
      let(:serializer) do
        Class.new(Serega) do
          attribute :name, method: :"full-name"
        end
      end

      let(:user) { double("full-name": "Ann Smith") }

      it "calls the method" do
        expect(builder.call([user], {}, nil, nil)).to eq [{name: "Ann Smith"}]
      end
    end

    context "when an attribute raises an error" do
      let(:user) { Struct.new(:name).new("Ann") }

      it "adds the attribute name to the error message" do
        expect { builder.call([user], {}, nil, nil) }
          .to raise_error(NoMethodError, /when serializing 'email' attribute/)
      end
    end

    context "when the cache is full" do
      before { stub_const("#{described_class}::MAX_BUILDERS", 1) }

      it "removes the oldest builder" do
        builder
        serializer::SeregaResultShape.builder(:struct, plan.points)

        expect(builder).not_to equal serializer::SeregaResultShape.builder(mode, plan.points)
      end
    end
  end
end
