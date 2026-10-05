# frozen_string_literal: true

RSpec.describe Serega::SeregaPlanPoint do
  let(:base) { Class.new(Serega) }

  def point_for(serializer, name)
    serializer::SeregaPlan.new(nil, {}).points.find { |point| point.name == name }
  end

  describe "#preloads" do
    it "returns the attribute's declared preloads" do
      serializer = Class.new(base) { attribute :author, preload: :author }
      expect(point_for(serializer, :author).preloads).to eq :author
    end

    it "is nil when the attribute declares no preloads" do
      serializer = Class.new(base) { attribute :name }
      expect(point_for(serializer, :name).preloads).to be_nil
    end
  end

  describe "#run_preloads" do
    let(:objects) { [double(:obj1), double(:obj2)] }

    it "passes the objects and preloads to the registered handler" do
      received = nil
      serializer = Class.new(base) do
        attribute :author, preload: {author: {}}
        preload_with(->(objects, preloads) { received = [objects, preloads] })
      end

      point_for(serializer, :author).run_preloads(objects)
      expect(received).to eq [objects, {author: {}}]
    end

    it "raises when the attribute has preloads but no handler is registered" do
      serializer = Class.new(base) { attribute :author, preload: :author }

      expect { point_for(serializer, :author).run_preloads(objects) }
        .to raise_error Serega::SeregaError, /requires a preload handler/
    end

    it "wraps handler errors with the attribute name and serializer class" do
      serializer = Class.new(base) do
        attribute :author, preload: :author
        preload_with(->(_objects, _preloads) { raise "boom" })
      end

      expect { point_for(serializer, :author).run_preloads(objects) }
        .to raise_error RuntimeError, end_with("(when serializing 'author' attribute in #{serializer})")
    end
  end

  describe "#load_batches" do
    it "loads each needed loader from the object group once and returns them keyed by name" do
      serializer = Class.new(base) do
        attribute :name
        attribute :online, batch: proc { |_objects| {} }
      end
      point = point_for(serializer, :online)
      loader = serializer.batch_loaders[:online]
      object_group = instance_double(Serega::SeregaObjectGroup)
      allow(object_group).to receive(:load_batch).with(loader).and_return("LOADED")

      expect(point.load_batches(object_group)).to eq(online: "LOADED")
      expect(object_group).to have_received(:load_batch).with(loader).once
    end

    it "wraps loading errors with the attribute name and serializer class" do
      serializer = Class.new(base) { attribute :online, batch: proc { |_objects| {} } }
      point = point_for(serializer, :online)
      object_group = instance_double(Serega::SeregaObjectGroup)
      allow(object_group).to receive(:load_batch).and_raise("boom")

      expect { point.load_batches(object_group) }
        .to raise_error RuntimeError, end_with("(when serializing 'online' attribute in #{serializer})")
    end
  end
end
