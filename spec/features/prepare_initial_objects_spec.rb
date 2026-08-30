# frozen_string_literal: true

RSpec.describe Serega do
  let(:serializer_class) { Class.new(described_class) }

  describe ".prepare_initial_objects" do
    it "returns nil when no handler was registered" do
      expect(serializer_class.prepare_initial_objects).to be_nil
    end

    it "registers and returns a block handler" do
      block = proc { |objects| objects }
      serializer_class.prepare_initial_objects(&block)
      expect(serializer_class.prepare_initial_objects).to equal block
    end

    it "registers a callable value handler" do
      handler = ->(objects) { objects }
      serializer_class.prepare_initial_objects(handler)
      expect(serializer_class.prepare_initial_objects).to equal handler
    end

    it "registers an object responding to #call" do
      handler = Class.new do
        def call(objects)
        end
      end.new
      serializer_class.prepare_initial_objects(handler)
      expect(serializer_class.prepare_initial_objects).to equal handler
    end

    it "replaces the previously registered handler" do
      first = ->(objects) { objects }
      second = ->(objects) { objects }
      serializer_class.prepare_initial_objects(first)
      serializer_class.prepare_initial_objects(second)

      expect(serializer_class.prepare_initial_objects).to equal second
    end

    it "raises when both a value and a block are given" do
      expect { serializer_class.prepare_initial_objects(proc { |a| }) { |a| } }
        .to raise_error Serega::SeregaError, "prepare_initial_objects accepts a single callable or a block, not both"
    end

    it "raises when the handler is not callable" do
      expect { serializer_class.prepare_initial_objects(:not_callable) }
        .to raise_error Serega::SeregaError, "prepare_initial_objects value must be a Proc or respond to #call"
    end

    it "raises when the handler has an unsupported signature" do
      error = <<~ERR.strip
        prepare_initial_objects handler arguments should have one of this signatures:
        - (objects)        # one argument
        - (objects, ctx)   # two arguments
        - (objects, ctx:)  # one argument and one :ctx keyword argument
      ERR
      expect { serializer_class.prepare_initial_objects(-> {}) }.to raise_error Serega::SeregaError, error
      expect { serializer_class.prepare_initial_objects(->(a, b, c) {}) }.to raise_error Serega::SeregaError, error
      expect { serializer_class.prepare_initial_objects(->(objects, foo:) {}) }.to raise_error Serega::SeregaError, error
      expect { serializer_class.prepare_initial_objects(proc {}) }.to raise_error Serega::SeregaError, error
    end
  end

  describe "Prepare initial objects functionality" do
    let(:records) { {"1" => {name: "Ann"}, "2" => {name: "Bob"}} }

    it "serializes objects returned by a block with one argument" do
      data = records
      serializer = Class.new(described_class) do
        prepare_initial_objects { |ids| ids.map { |id| data[id] } }
        attribute :name, value: proc { |record| record[:name] }
      end

      expect(serializer.to_h(["1", "2"])).to eq [{name: "Ann"}, {name: "Bob"}]
    end

    it "provides context to a block with two arguments" do
      received = nil
      serializer = Class.new(described_class) do
        prepare_initial_objects { |ids, ctx| received = [ids, ctx] }
        attribute :itself, value: proc { |obj| obj }
      end

      serializer.to_h(["1"], context: {foo: :bar})
      expect(received).to eq [["1"], {foo: :bar}]
    end

    it "provides context to a block with a :ctx keyword argument" do
      received = nil
      serializer = Class.new(described_class) do
        prepare_initial_objects { |ids, ctx:| received = [ids, ctx] }
        attribute :itself, value: proc { |obj| obj }
      end

      serializer.to_h(["1"], context: {foo: :bar})
      expect(received).to eq [["1"], {foo: :bar}]
    end

    it "serializes objects returned by a callable value with one argument" do
      data = records
      handler = Class.new do
        define_method(:call) { |ids| ids.map { |id| data[id] } }
      end.new
      serializer = Class.new(described_class) do
        prepare_initial_objects handler
        attribute :name, value: proc { |record| record[:name] }
      end

      expect(serializer.to_h(["1"])).to eq [{name: "Ann"}]
    end

    it "provides context to a callable value with two arguments" do
      received = nil
      handler = Class.new do
        define_method(:call) { |ids, ctx| received = [ids, ctx] }
      end.new
      serializer = Class.new(described_class) do
        prepare_initial_objects handler
        attribute :itself, value: proc { |obj| obj }
      end

      serializer.to_h(["1"], context: {foo: :bar})
      expect(received).to eq [["1"], {foo: :bar}]
    end

    it "provides context to a callable value with a :ctx keyword argument" do
      received = nil
      handler = Class.new do
        define_method(:call) { |ids, ctx:| received = [ids, ctx] }
      end.new
      serializer = Class.new(described_class) do
        prepare_initial_objects handler
        attribute :itself, value: proc { |obj| obj }
      end

      serializer.to_h(["1"], context: {foo: :bar})
      expect(received).to eq [["1"], {foo: :bar}]
    end

    it "detects :many from the prepared objects when a single object becomes a collection" do
      serializer = Class.new(described_class) do
        prepare_initial_objects { |id| [id] }
        attribute :itself, value: proc { |obj| obj }
      end

      expect(serializer.to_h("1")).to eq [{itself: "1"}]
    end

    it "detects :many from the prepared objects when a collection becomes a single object" do
      serializer = Class.new(described_class) do
        prepare_initial_objects { |ids| ids.first }
        attribute :itself, value: proc { |obj| obj }
      end

      expect(serializer.to_h(["1", "2"])).to eq({itself: "1"})
    end

    it "uses provided :many option instead of detecting it" do
      serializer = Class.new(described_class) do
        prepare_initial_objects { |ids| ids.first }
        attribute :itself, value: proc { |obj| obj }
      end

      expect(serializer.to_h(["1"], many: true)).to eq [{itself: "1"}]
      expect(serializer.to_h(["1"], many: false)).to eq({itself: "1"})
    end

    it "serializes nil when the handler returns nil" do
      serializer = Class.new(described_class) do
        prepare_initial_objects { |ids| nil }
        attribute :itself, value: proc { |obj| obj }
      end

      expect(serializer.to_h(["1"])).to be_nil
    end

    it "provides nil to the handler when nil is serialized" do
      received = :not_called
      serializer = Class.new(described_class) do
        prepare_initial_objects { |objects| received = objects }
        attribute :itself, value: proc { |obj| obj }
      end

      serializer.to_h(nil)
      expect(received).to be_nil
    end

    it "prepares objects in all serialization methods" do
      count = 0
      handler = lambda do |objects|
        count += 1
        objects
      end
      serializer = Class.new(described_class) do
        prepare_initial_objects handler
        attribute :itself, value: proc { |obj| obj }
      end

      serializer.call("1")
      serializer.to_h("1")
      serializer.to_data("1")
      serializer.new.call("1")
      serializer.new.to_h("1")
      serializer.new.to_data("1")

      expect(count).to eq 6
    end

    it "prepares objects once per serialization regardless of objects count" do
      count = 0
      handler = lambda do |objects|
        count += 1
        objects
      end
      serializer = Class.new(described_class) do
        prepare_initial_objects handler
        attribute :itself, value: proc { |obj| obj }
      end

      serializer.to_h(["1", "2", "3"])
      expect(count).to eq 1
    end

    it "prepares objects to Data objects" do
      data = records
      serializer = Class.new(described_class) do
        prepare_initial_objects { |ids| ids.map { |id| data[id] } }
        attribute :name, value: proc { |record| record[:name] }
      end

      expect(serializer.to_data(["1"]).first.name).to eq "Ann"
    end

    it "returns nil from to_data when the handler returns nil" do
      serializer = Class.new(described_class) do
        prepare_initial_objects { |ids| nil }
        attribute :itself, value: proc { |obj| obj }
      end

      expect(serializer.to_data(["1"])).to be_nil
    end

    it "raises errors from the handler without wrapping them" do
      serializer = Class.new(described_class) do
        prepare_initial_objects { |ids| foo } # not existing variable call
        attribute :itself, value: proc { |obj| obj }
      end

      expect { serializer.to_h(["1"]) }.to raise_error NameError do |error|
        expect(error.message).not_to include "when serializing"
      end
    end

    it "accepts string keys and nil serialization options" do
      received = []
      serializer = Class.new(described_class) do
        prepare_initial_objects { |objects, ctx| received << ctx }
        attribute :itself, value: proc { |obj| obj }
      end

      serializer.to_h("1")
      serializer.to_h("1", "context" => {foo: :bar})

      expect(received).to eq [{}, {foo: :bar}]
    end

    it "does not modify provided serialization options" do
      serializer = Class.new(described_class) do
        prepare_initial_objects { |objects| objects }
        attribute :itself, value: proc { |obj| obj }
      end

      opts = {many: false}
      serializer.to_h("1", opts)
      expect(opts).to eq({many: false})
    end

    it "prepares objects gathered by the preload handler" do
      received = nil
      serializer = Class.new(described_class) do
        prepare_initial_objects { |ids| ids.map(&:to_i) }
        preload_with { |objects, preloads| received = objects }
        attribute :itself, preload: :assoc, value: proc { |obj| obj }
      end

      serializer.to_h(["1", "2"])
      expect(received).to eq [1, 2]
    end
  end
end
