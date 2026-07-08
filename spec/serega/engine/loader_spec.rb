# frozen_string_literal: true

RSpec.describe Serega::SeregaEngine::Loader do
  subject(:loader) { serializer_class.batch(name, block) }

  let(:serializer_class) { Class.new(Serega) }
  let(:name) { :test_attribute }
  let(:block) { proc { |objects| objects.map(&:id) } }

  describe "#initialize" do
    it "sets name as symbol" do
      expect(loader.name).to eq(:test_attribute)
    end

    it "sets block" do
      expect(loader.block).to eq(block)
    end

    it "freezes initials" do
      expect(loader.initials).to be_frozen
      expect(loader.initials[:name]).to be_frozen
    end

    context "when name is string" do
      let(:name) { "test_attribute" }

      it "converts name to symbol" do
        expect(loader.name).to eq(:test_attribute)
      end
    end
  end

  describe "#load" do
    let(:objects) { [double(id: 1), double(id: 2)] }
    let(:context) { {user: double} }

    context "when block takes one argument" do
      let(:block) { proc { |objects| objects.map(&:id) } }

      it "calls block with objects only" do
        allow(block).to receive(:call)
        loader.load(objects, context)

        expect(block).to have_received(:call).with(objects)
      end
    end

    context "when block takes two arguments" do
      let(:block) { proc { |objects, context| objects.map { |obj| "#{obj.id}-#{context[:user].id}" } } }

      it "calls block with objects and context" do
        allow(block).to receive(:call)
        loader.load(objects, context)

        expect(block).to have_received(:call).with(objects, context)
      end
    end

    context "when block takes keyword arguments" do
      let(:block) { proc { |objects, ctx:| objects.map { |obj| "#{obj.id}-#{ctx[:user].id}" } } }

      it "calls block with objects and ctx keyword argument" do
        allow(block).to receive(:call)
        loader.load(objects, context)

        expect(block).to have_received(:call).with(objects, ctx: context)
      end
    end
  end
end
