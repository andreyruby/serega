# frozen_string_literal: true

RSpec.describe Serega do
  let(:serializer_class) { Class.new(described_class) }

  describe ".preload_with" do
    it "returns nil when no handler was registered" do
      expect(serializer_class.preload_with).to be_nil
    end

    it "registers and returns a block handler" do
      block = proc { |objects, preloads| [objects, preloads] }
      serializer_class.preload_with(&block)
      expect(serializer_class.preload_with).to equal block
    end

    it "registers a callable value handler" do
      handler = ->(objects, preloads) { [objects, preloads] }
      serializer_class.preload_with(handler)
      expect(serializer_class.preload_with).to equal handler
    end

    it "registers an object responding to #call with two arguments" do
      handler = Class.new do
        def call(objects, preloads)
        end
      end.new
      serializer_class.preload_with(handler)
      expect(serializer_class.preload_with).to equal handler
    end

    it "raises when both a value and a block are given" do
      expect { serializer_class.preload_with(proc { |a, b| }) { |a, b| } }
        .to raise_error Serega::SeregaError, "preload_with accepts a single callable or a block, not both"
    end

    it "raises when the handler is not callable" do
      expect { serializer_class.preload_with(:not_callable) }
        .to raise_error Serega::SeregaError, "preload_with value must be a Proc or respond to #call"
    end

    it "raises when the handler does not accept two positional arguments" do
      error = "preload_with handler must accept two positional arguments: (objects, preloads)"
      expect { serializer_class.preload_with(->(objects) {}) }.to raise_error Serega::SeregaError, error
      expect { serializer_class.preload_with(->(a, b, c) {}) }.to raise_error Serega::SeregaError, error
      expect { serializer_class.preload_with(->(objects, ctx:) {}) }.to raise_error Serega::SeregaError, error
    end
  end

  describe "Preloads functionality" do
    let(:serializer_class) { Class.new(described_class) }

    describe "attribute preloads" do
      it "allows manual preload specification" do
        serializer_class.attribute :name, preload: :user_profile
        attribute = serializer_class.attributes[:name]
        expect(attribute.preloads).to eq(:user_profile)
      end

      it "auto-preloads for delegate when configured" do
        serializer_class.config.auto_preload = {has_delegate_option: true}
        serializer_class.attribute :name, delegate: {to: :profile}
        attribute = serializer_class.attributes[:name]
        expect(attribute.preloads).to eq(:profile)
      end

      it "auto-preloads for serializer when configured" do
        other_serializer = Class.new(described_class)
        serializer_class.config.auto_preload = {has_serializer_option: true}
        serializer_class.attribute :profile, serializer: other_serializer
        attribute = serializer_class.attributes[:profile]
        expect(attribute.preloads).to eq(:profile)
      end

      it "auto-hides attributes with preloads when configured" do
        serializer_class.config.hide_by_default = :auto
        serializer_class.attribute :name, preload: :user_profile
        attribute = serializer_class.attributes[:name]
        expect(attribute.hide).to be true
      end

      it "allows disabling preloads with false" do
        serializer_class.attribute :name, preload: false
        attribute = serializer_class.attributes[:name]
        expect(attribute.preloads).to be_nil
      end
    end

    describe "validation" do
      it "validates preload option cannot be used with const" do
        expect {
          serializer_class.attribute :name, preload: :profile, const: "value"
        }.to raise_error Serega::SeregaError, "Option :preload can not be used together with option :const"
      end

      it "validates preload option value can not be `true`" do
        expect {
          serializer_class.attribute :name, preload: true
        }.to raise_error Serega::SeregaError, "Option :preload value can not be `true`"
      end

      it "allows preload option value to be `false`" do
        expect { serializer_class.attribute :name, preload: false }.not_to raise_error
      end
    end

    describe "preload_with wiring" do
      it "invokes the handler with the gathered objects and the attribute preloads" do
        received = nil
        serializer = Class.new(described_class) do
          preload_with { |objects, preloads| received = [objects, preloads] }
          attribute :value, preload: :assoc, value: proc { |obj| obj }
        end

        serializer.to_h([1, 2])
        expect(received).to eq [[1, 2], :assoc]
      end

      it "does not invoke the handler for attributes without preloads" do
        called = false
        serializer = Class.new(described_class) do
          preload_with { |objects, preloads| called = true }
          attribute :value, value: proc { |obj| obj }
        end

        serializer.to_h([1])
        expect(called).to be false
      end

      it "invokes the handler once for an attribute with multiple batch loaders" do
        calls = []
        serializer = Class.new(described_class) do
          preload_with { |objects, preloads| calls << preloads }
          batch(:a) { |objects| objects.to_h { |object| [object, object] } }
          batch(:b) { |objects| objects.to_h { |object| [object, object] } }
          attribute(:value, batch: {use: [:a, :b]}, preload: :assoc, value: proc { |obj, batches:| obj })
        end

        serializer.to_h([1, 2])
        expect(calls).to eq [:assoc]
      end

      it "raises when an attribute declares :preload but no handler is registered" do
        serializer = Class.new(described_class) do
          attribute :value, preload: :assoc, value: proc { |obj| obj }
        end

        error = "The :preload option requires a preload handler. Register one with `preload_with` (the :activerecord_preloads plugin does this for you).\n(when serializing 'value' attribute in #{serializer})"
        expect { serializer.to_h([1]) }.to raise_error Serega::SeregaError, error
      end

      it "raises when a nested attribute declares :preload but its serializer has no handler" do
        child = Class.new(described_class) do
          attribute :name, preload: :profile, value: proc { |obj| obj }
        end
        parent = Class.new(described_class) do
          attribute :child, serializer: child, value: proc { |obj| obj }
        end

        error = "The :preload option requires a preload handler. Register one with `preload_with` (the :activerecord_preloads plugin does this for you).\n(when serializing 'name' attribute in #{child})"
        expect { parent.to_h([1]) }.to raise_error Serega::SeregaError, error
      end
    end
  end
end
