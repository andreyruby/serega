# frozen_string_literal: true

RSpec.describe Serega::SeregaBatch do
  describe Serega::SeregaBatch::AttributeLoaders do
    subject(:loaders) { described_class.new }

    let(:serializer) { Class.new(Serega) }
    let(:attacher) { "ATTACHER" }
    let(:point_class) { class_double(serializer::SeregaPlanPoint, serializer_class: serializer) }

    describe "#remember" do
      let(:point) { instance_double(serializer::SeregaPlanPoint, class: point_class) }
      let(:object) { double }
      let(:container) { double }

      it "creates new point batch loader for new point" do
        loaders.remember(point, object, attacher)
        expect(loaders.send(:point_batch_loaders).size).to eq(1)
        expect(loaders.send(:point_batch_loaders).first).to be_a(Serega::SeregaBatch::AttributeLoader)
      end

      it "reuses existing point batch loader for same point" do
        loaders.remember(point, object, attacher)
        loaders.remember(point, object, attacher)
        expect(loaders.send(:point_batch_loaders).size).to eq(1)
      end

      it "creates separate point batch loader for different points" do
        point2 = instance_double(serializer::SeregaPlanPoint, class: point_class)
        loaders.remember(point, object, attacher)
        loaders.remember(point2, object, attacher)
        expect(loaders.send(:point_batch_loaders).size).to eq(2)
      end
    end

    describe "#load_all" do
      let(:context) { double }
      let(:point1) { instance_double(serializer::SeregaPlanPoint, class: point_class) }
      let(:point2) { instance_double(serializer::SeregaPlanPoint, class: point_class) }
      let(:object) { double }
      let(:container) { double }

      before do
        loaders.remember(point1, object, attacher)
        loaders.remember(point2, object, attacher)
      end

      it "loads all point batch loaders" do
        point_loader1 = loaders.send(:point_batch_loaders).first
        point_loader2 = loaders.send(:point_batch_loaders).last
        allow(point_loader1).to receive(:load_all)
        allow(point_loader2).to receive(:load_all)

        loaders.load_all(context)

        expect(point_loader1).to have_received(:load_all).with(context)
        expect(point_loader2).to have_received(:load_all).with(context)
      end
    end
  end
end
