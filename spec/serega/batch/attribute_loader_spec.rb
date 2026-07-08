# frozen_string_literal: true

RSpec.describe Serega::SeregaBatch do
  describe Serega::SeregaBatch::AttributeLoader do
    subject(:attribute_loader) { described_class.new(point, level) }

    let(:point) { double(class: double(serializer_class: serializer_class), attribute: double(preloads: nil)) }
    let(:serializer_class) { double }
    let(:level) { instance_double(Serega::SeregaBatch::Level) }
    let(:batch_loader) { double }
    let(:batch_data) { {1 => "John", 2 => "Jane"} }

    describe "#store" do
      let(:object) { double }

      it "adds object and attacher to collection" do
        attribute_loader.store(object, "attacher")
        expect(attribute_loader.send(:serialized_object_attachers)).to eq [[object, "attacher"]]
      end

      it "stores same object multiple times" do
        attribute_loader.store(object, "attacher1")
        attribute_loader.store(object, "attacher2")
        expect(attribute_loader.send(:serialized_object_attachers)).to eq [
          [object, "attacher1"],
          [object, "attacher2"]
        ]
      end
    end

    describe "#load_batch" do
      it "loads batch values for the given loader via the level" do
        allow(level).to receive(:load).with(batch_loader).and_return(batch_data)

        expect(attribute_loader.load_batch(batch_loader)).to eq batch_data
        expect(level).to have_received(:load).with(batch_loader)
      end
    end

    describe "#attach" do
      let(:object1) { double }
      let(:object2) { double }
      let(:attacher1) { double(call: nil) }
      let(:attacher2) { double(call: nil) }
      let(:batches) { {user: batch_data} }

      before do
        attribute_loader.store(object1, attacher1)
        attribute_loader.store(object2, attacher2)
      end

      it "calls each attacher with its object and the loaded batches" do
        attribute_loader.attach(batches)

        expect(attacher1).to have_received(:call).with(object1, batches)
        expect(attacher2).to have_received(:call).with(object2, batches)
      end

      it "annotates an attacher error with the attribute name and serializer" do
        allow(point).to receive(:name).and_return(:full_name)
        failing = ->(_object, _batches) { raise "boom resolving value" }
        attribute_loader.store(object1, failing)

        expect { attribute_loader.attach(batches) }
          .to raise_error(RuntimeError, /boom resolving value.*when serializing 'full_name' attribute in/m)
      end
    end
  end
end
