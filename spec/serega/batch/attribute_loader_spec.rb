# frozen_string_literal: true

RSpec.describe Serega::SeregaBatch do
  describe Serega::SeregaBatch::AttributeLoader do
    subject(:loader) { described_class.new(point) }

    let(:point) { double(class: double(serializer_class: serializer_class)) }
    let(:serializer_class) { double(batch_loaders: batch_loaders) }
    let(:batch_loaders) { {user: batch_loader} }
    let(:batch_loader) { double(load: batch_data) }
    let(:batch_data) { {1 => "John", 2 => "Jane"} }

    describe "#store" do
      let(:serializer) { double(__send__: nil) }
      let(:object) { double }
      let(:container) { double }

      it "adds objects and attachers to collection" do
        loader.store(object, "attacher")
        expect(loader.send(:objects)).to eq([object])
        expect(loader.send(:serialized_object_attachers)).to eq [[object, "attacher"]]
      end

      it "stores same objects multiple times" do
        loader.store(object, "attacher1")
        loader.store(object, "attacher2")
        expect(loader.send(:objects)).to eq([object, object])
        expect(loader.send(:serialized_object_attachers)).to eq [
          [object, "attacher1"],
          [object, "attacher2"]
        ]
      end
    end

    describe "#load_all" do
      let(:serializer) { double(__send__: nil) }
      let(:object1) { double(id: 1) }
      let(:object2) { double(id: 2) }
      let(:attacher1) { double(call: nil) }
      let(:attacher2) { double(call: nil) }
      let(:context) { double }

      before do
        allow(point).to receive(:batch_loaders).and_return([:user])
        loader.store(object1, attacher1)
        loader.store(object2, attacher2)
      end

      it "loads all batch values and attaches them" do
        allow(serializer).to receive(:__send__)
        loader.load_all(context)
        expect(batch_loader).to have_received(:load).with([object1, object2], context)

        expect(attacher1).to have_received(:call).with(object1, {user: batch_data})
        expect(attacher2).to have_received(:call).with(object2, {user: batch_data})
      end
    end
  end
end
