# frozen_string_literal: true

RSpec.describe Serega::SeregaPlanPoint do
  let(:base) { Class.new(Serega) }
  let(:child_serializer_class) do
    Class.new(base) { attribute :name }
  end

  def point_for(serializer, name)
    serializer::SeregaPlan.call({}).points.find { |point| point.name == name }
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

    it "returns nil without calling the handler when there are no preloads" do
      serializer = Class.new(base) do
        attribute :name
        preload_with(->(_objects, _preloads) { raise "should not be called" })
      end

      expect(point_for(serializer, :name).run_preloads(objects)).to be_nil
    end

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
    it "is nil when the point needs no batch loaders" do
      serializer = Class.new(base) { attribute :name }
      expect(point_for(serializer, :name).load_batches(double(:level))).to be_nil
    end

    it "fetches each needed loader from the level once and returns them keyed by name" do
      serializer = Class.new(base) do
        attribute :name
        attribute :online, batch: proc { |_objects| {} }
      end
      point = point_for(serializer, :online)
      loader = serializer.batch_loaders[:online]
      level = instance_double(Serega::SeregaEngine::Level)
      allow(level).to receive(:fetch).with(loader).and_return("LOADED")

      expect(point.load_batches(level)).to eq(online: "LOADED")
      expect(level).to have_received(:fetch).with(loader).once
    end

    it "wraps loading errors with the attribute name and serializer class" do
      serializer = Class.new(base) { attribute :online, batch: proc { |_objects| {} } }
      point = point_for(serializer, :online)
      level = instance_double(Serega::SeregaEngine::Level)
      allow(level).to receive(:fetch).and_raise("boom")

      expect { point.load_batches(level) }
        .to raise_error RuntimeError, end_with("(when serializing 'online' attribute in #{serializer})")
    end
  end

  describe "#child_serializer" do
    let(:context) { {locale: :en} }
    let(:level_queue) { Serega::SeregaEngine::LevelQueue.new }

    it "is nil for a plain attribute with no child plan" do
      serializer = Class.new(base) { attribute :name }
      expect(point_for(serializer, :name).child_serializer(context: context, level_queue: level_queue)).to be_nil
    end

    it "builds the child object serializer with the point's child plan, many and the given runtime opts" do
      child = child_serializer_class
      serializer = Class.new(base) { attribute :posts, serializer: child, many: true }
      point = point_for(serializer, :posts)

      result = point.child_serializer(context: context, level_queue: level_queue)

      expect(result).to be_a child::SeregaObjectSerializer
      expect(result.plan).to equal point.child_plan
      expect(result.context).to equal context
      expect(result.many).to be true
      expect(result.level_queue).to equal level_queue
    end
  end
end
