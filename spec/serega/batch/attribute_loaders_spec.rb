# frozen_string_literal: true

RSpec.describe Serega::SeregaBatch do
  describe Serega::SeregaBatch::AttributeLoaders do
    subject(:loaders) { described_class.new(context) }

    let(:context) { "CONTEXT" }
    let(:attacher) { "ATTACHER" }
    let(:serializer) { Class.new(Serega) }
    let(:plan) { double(:plan) }
    let(:point_class) { class_double(serializer::SeregaPlanPoint, serializer_class: serializer) }

    describe "#add_objects" do
      it "gathers objects into one level per plan" do
        loaders.add_objects(plan, [1, 2])
        loaders.add_objects(plan, [3])

        level = loaders.send(:levels)[plan]
        expect(level).to be_a(Serega::SeregaBatch::Level)
        expect(level.objects).to eq [1, 2, 3]
      end

      it "uses separate levels for different plans" do
        plan2 = double(:plan2)
        loaders.add_objects(plan, [1])
        loaders.add_objects(plan2, [2])

        expect(loaders.send(:levels)[plan].objects).to eq [1]
        expect(loaders.send(:levels)[plan2].objects).to eq [2]
      end
    end

    describe "#remember" do
      let(:point) { instance_double(serializer::SeregaPlanPoint, class: point_class, plan: plan) }
      let(:object) { double }

      it "creates new attribute loader for new point" do
        loaders.remember(point, object, attacher)
        expect(loaders.send(:attribute_loaders).size).to eq(1)
        expect(loaders.send(:attribute_loaders).first).to be_a(Serega::SeregaBatch::AttributeLoader)
      end

      it "reuses existing attribute loader for same point" do
        loaders.remember(point, object, attacher)
        loaders.remember(point, object, attacher)
        expect(loaders.send(:attribute_loaders).size).to eq(1)
      end

      it "creates separate attribute loader for different points" do
        point2 = instance_double(serializer::SeregaPlanPoint, class: point_class, plan: plan)
        loaders.remember(point, object, attacher)
        loaders.remember(point2, object, attacher)
        expect(loaders.send(:attribute_loaders).size).to eq(2)
      end
    end

    describe "#load_all" do
      let(:point1) { instance_double(serializer::SeregaPlanPoint, class: point_class, plan: plan, batch_loaders: [], attribute: double(preloads: nil)) }
      let(:point2) { instance_double(serializer::SeregaPlanPoint, class: point_class, plan: plan, batch_loaders: [], attribute: double(preloads: nil)) }
      let(:object) { double }

      before do
        loaders.remember(point1, object, attacher)
        loaders.remember(point2, object, attacher)
      end

      it "attaches loaded batches to every attribute loader" do
        attribute_loader1 = loaders.send(:attribute_loaders).first
        attribute_loader2 = loaders.send(:attribute_loaders).last
        allow(attribute_loader1).to receive(:attach)
        allow(attribute_loader2).to receive(:attach)

        loaders.load_all

        expect(attribute_loader1).to have_received(:attach).with({})
        expect(attribute_loader2).to have_received(:attach).with({})
      end
    end
  end
end
