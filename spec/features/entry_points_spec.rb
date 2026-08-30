# frozen_string_literal: true

RSpec.describe Serega do
  let(:serializer_class) { Class.new(described_class) }

  describe "serialization methods" do
    let(:serializer_class) do
      Class.new(described_class) do
        attribute(:obj, value: proc { |obj| obj })
        attribute(:ctx, value: proc { |obj, ctx| ctx[:data] })
        attribute(:except, const: "EXCEPT")
      end
    end

    let(:modifiers) { {except: :except} }
    let(:serialize_opts) { {context: {data: "bar"}} }

    let(:serializer) { serializer_class.new(modifiers) }

    describe "#call" do
      it "returns serialized response" do
        expect(serializer.call("foo", serialize_opts)).to eq({obj: "foo", ctx: "bar"})
      end

      context "with string opts" do
        before do
          modifiers.transform_keys!(&:to_s)
          serialize_opts.transform_keys!(&:to_s)
        end

        it "returns correct response when options provided with string keys" do
          expect(serializer.call("foo", serialize_opts)).to eq({obj: "foo", ctx: "bar"})
        end
      end
    end

    describe "#to_h" do
      it "returns serialized response same as .call method" do
        expect(serializer.to_h("foo", serialize_opts)).to eq({obj: "foo", ctx: "bar"})
      end
    end

    describe ".call" do
      it "returns serialized to response" do
        expect(serializer_class.call("foo", modifiers.merge(serialize_opts))).to eq({obj: "foo", ctx: "bar"})
      end

      context "with string opts" do
        before do
          modifiers.transform_keys!(&:to_s)
          serialize_opts.transform_keys!(&:to_s)
        end

        it "returns correct response when options provided with string keys" do
          expect(serializer_class.call("foo", modifiers.merge(serialize_opts))).to eq({obj: "foo", ctx: "bar"})
        end
      end
    end

    describe ".to_h" do
      it "returns serialized response same as .call method" do
        expect(serializer_class.to_h("foo", modifiers.merge(serialize_opts))).to eq({obj: "foo", ctx: "bar"})
      end
    end

    describe "#to_data" do
      it "returns a Data object with correct members" do
        result = serializer.to_data("foo", serialize_opts)
        expect(result).to be_a(Data)
        expect(result.obj).to eq "foo"
        expect(result.ctx).to eq "bar"
      end

      it "returns nil when object is nil" do
        expect(serializer.to_data(nil, serialize_opts)).to be_nil
      end

      context "with string opts" do
        before do
          modifiers.transform_keys!(&:to_s)
          serialize_opts.transform_keys!(&:to_s)
        end

        it "returns correct response when options provided with string keys" do
          result = serializer.to_data("foo", serialize_opts)
          expect(result.obj).to eq "foo"
          expect(result.ctx).to eq "bar"
        end
      end
    end

    describe ".to_data" do
      it "returns a Data object with correct members" do
        result = serializer_class.to_data("foo", modifiers.merge(serialize_opts))
        expect(result).to be_a(Data)
        expect(result.obj).to eq "foo"
        expect(result.ctx).to eq "bar"
      end

      it "returns nil when object is nil" do
        expect(serializer_class.to_data(nil, modifiers.merge(serialize_opts))).to be_nil
      end

      context "with string opts" do
        before do
          modifiers.transform_keys!(&:to_s)
          serialize_opts.transform_keys!(&:to_s)
        end

        it "returns correct response when options provided with string keys" do
          result = serializer_class.to_data("foo", modifiers.merge(serialize_opts))
          expect(result.obj).to eq "foo"
          expect(result.ctx).to eq "bar"
        end
      end
    end
  end
end
