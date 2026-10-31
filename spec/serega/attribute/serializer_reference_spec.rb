# frozen_string_literal: true

RSpec.describe Serega::SeregaAttribute::SerializerReference do
  let(:reference) { described_class.new(serializer) }
  let(:serializer_class) { Class.new(Serega) }

  describe "#resolve" do
    subject(:resolved) { reference.resolve }

    context "with a serializer class" do
      let(:serializer) { serializer_class }

      it "returns the class" do
        expect(resolved).to be serializer_class
      end
    end

    context "with a Proc" do
      let(:serializer) { proc { serializer_class } }

      it "returns the class that the Proc returns" do
        expect(resolved).to be serializer_class
      end
    end

    context "with a class name" do
      let(:serializer) { "SerializerReferenceSpecSerializer" }

      before { stub_const("SerializerReferenceSpecSerializer", serializer_class) }

      it "returns the class of the name" do
        expect(resolved).to be serializer_class
      end
    end

    context "with a Proc resolved before" do
      let(:serializer) { proc { Class.new(Serega) } }

      it "returns the class of the first call" do
        expect(resolved).to be reference.resolve
      end
    end

    context "with a frozen reference" do
      let(:serializer) { proc { Class.new(Serega) } }
      let(:reference) { described_class.new(serializer).freeze }

      it "calls the Proc on each call" do
        expect(resolved).not_to be reference.resolve
      end
    end
  end
end
