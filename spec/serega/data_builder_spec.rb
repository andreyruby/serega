# frozen_string_literal: true

RSpec.describe Serega::SeregaDataBuilder do
  let(:base_class) { Class.new(Serega) }

  describe ".call" do
    context "with a flat serializer" do
      let(:serializer_class) do
        Class.new(base_class) do
          attribute :id, const: 1
          attribute :name, const: "Alice"
        end
      end

      it "returns a Data object with correct members" do
        serializer = serializer_class.new
        result = serializer.to_data(Object.new)
        expect(result).to be_a(Data)
        expect(result.id).to eq 1
        expect(result.name).to eq "Alice"
      end

      it "returns an array of Data objects for a collection" do
        result = serializer_class.to_data([Object.new, Object.new])
        expect(result).to be_an(Array)
        expect(result).to all(be_a(Data))
        expect(result.map(&:id)).to eq [1, 1]
      end

      it "returns nil when object is nil" do
        result = serializer_class.to_data(nil)
        expect(result).to be_nil
      end
    end

    context "with a nested serializer" do
      let(:nested_class) do
        Class.new(base_class) do
          attribute :city, const: "NYC"
          attribute :zip, const: "10001"
        end
      end

      let(:serializer_class) do
        nc = nested_class
        Class.new(base_class) do
          attribute :id, const: 42
          attribute :address, serializer: nc, const: Object.new
        end
      end

      it "wraps nested hashes in Data objects" do
        result = serializer_class.to_data(Object.new)
        expect(result).to be_a(Data)
        expect(result.id).to eq 42
        expect(result.address).to be_a(Data)
        expect(result.address.city).to eq "NYC"
        expect(result.address.zip).to eq "10001"
      end

      it "handles nil nested values without raising" do
        nc = nested_class
        serializer_class = Class.new(base_class) do
          attribute :id, const: 1
          attribute :address, serializer: nc, const: nil
        end
        result = serializer_class.to_data(Object.new)
        expect(result.address).to be_nil
      end
    end

    context "with a nested collection" do
      let(:item_class) do
        Class.new(base_class) do
          attribute :val, const: 7
        end
      end

      let(:serializer_class) do
        ic = item_class
        Class.new(base_class) do
          attribute :items, serializer: ic, many: true, const: [Object.new, Object.new]
        end
      end

      it "wraps each element of a nested array in Data objects" do
        result = serializer_class.to_data(Object.new)
        expect(result.items).to be_an(Array)
        expect(result.items).to all(be_a(Data))
        expect(result.items.map(&:val)).to eq [7, 7]
      end
    end

    context "with Data class caching" do
      it "reuses the same Data class for plans with identical fields" do
        serializer_class = Class.new(base_class) do
          attribute :x, const: 1
          attribute :y, const: 2
        end

        r1 = serializer_class.to_data(Object.new)
        r2 = serializer_class.to_data(Object.new)
        expect(r1.class).to equal(r2.class)
      end

      it "uses different Data classes when fields differ due to modifiers" do
        serializer_class = Class.new(base_class) do
          attribute :x, const: 1
          attribute :y, const: 2
        end

        full = serializer_class.to_data(Object.new)
        partial = serializer_class.to_data(Object.new, only: :x)
        expect(full.class).not_to equal(partial.class)
        expect(full.members).to match_array(%i[x y])
        expect(partial.members).to eq %i[x]
      end

      it "uses the same Data class across distinct plan instances with the same fields" do
        serializer_class = Class.new(base_class) do
          attribute :a, const: 1
        end

        # No plan caching (default max_cached_plans_per_serializer_count = 0),
        # so each call builds a new plan instance — but the Data class is shared.
        r1 = serializer_class.to_data(Object.new, only: :a)
        r2 = serializer_class.to_data(Object.new, only: :a)
        expect(r1.class).to equal(r2.class)
      end
    end
  end

  describe "SeregaDataBuilder inheritance" do
    it "creates a subclass for each serializer" do
      serializer_class = Class.new(base_class)
      expect(serializer_class::SeregaDataBuilder.superclass).to equal(base_class::SeregaDataBuilder)
    end

    it "assigns serializer_class to each subclass" do
      serializer_class = Class.new(base_class)
      expect(serializer_class::SeregaDataBuilder.serializer_class).to equal(serializer_class)
    end
  end
end
