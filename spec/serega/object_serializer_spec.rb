# frozen_string_literal: true

RSpec.describe Serega::SeregaObjectSerializer do
  let(:serializer_class) { Class.new(Serega) }
  let(:object_serializer) { serializer_class::SeregaObjectSerializer }
  let(:context) { {} }

  describe ".serializer_class" do
    it "returns self @serializer_class" do
      expect(object_serializer.serializer_class).to equal serializer_class
    end
  end

  describe "serialization" do
    def serialize(object)
      level_queue = Serega::SeregaEngine::LevelQueue.new
      result = object_serializer.new(context: context, plan: plan, level_queue: level_queue).serialize(object)
      level_queue.run
      result
    end

    let(:serializer_class) do
      Class.new(Serega) do
        attribute(:foo, const: "bar")
      end
    end

    context "when no nested serializers" do
      let(:plan) { serializer_class::SeregaPlan.new(nil, {only: {foo: {}}}) }

      it "serializes object to hash" do
        expect(serialize(1)).to eq(foo: "bar")
      end

      it "serializes array to array of hashes" do
        expect(serialize([1, 1])).to eq([{foo: "bar"}, {foo: "bar"}])
      end

      it "raises any error with additional serializer name and attribute name in error message" do
        serializer_class.attribute :foo, delegate: {to: :bar} # no `bar` method in Integer

        expect { serialize(1) }.to raise_error NoMethodError,
          end_with("(when serializing 'foo' attribute in #{serializer_class})")
      end
    end

    context "with nested serializers" do
      before do
        serializer_class.attribute(:hash, serializer: serializer_class, const: 1, hide: true)
        serializer_class.attribute(:array, serializer: serializer_class, const: [1, 1], hide: true)
      end

      it "serializes nested object to hash and nested array to array of hashes" do
        result = serializer_class.call(1, only: {foo: {}, hash: {foo: {}}, array: {foo: {}}})
        expect(result).to eq(
          foo: "bar",
          hash: {foo: "bar"},
          array: [{foo: "bar"}, {foo: "bar"}]
        )
      end
    end
  end
end
