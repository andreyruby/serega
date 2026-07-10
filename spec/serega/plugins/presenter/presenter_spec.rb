# frozen_string_literal: true

load_plugin_code :presenter

RSpec.describe Serega::SeregaPlugins::Presenter do
  let(:serializer) { Class.new(Serega) { plugin :presenter } }

  describe "loading" do
    it "adds serializer::Presenter class" do
      expect(serializer::Presenter).to be_a Class
    end

    it "appends :__getobj__ to auto_preload_excluded_methods" do
      expect(serializer.config.auto_preload_excluded_methods).to eq %i[itself __getobj__]
    end

    it "preserves customized auto_preload_excluded_methods when appending :__getobj__" do
      custom_serializer = Class.new(Serega) do
        config.auto_preload_excluded_methods = %i[current_object]
        plugin :presenter
      end

      expect(custom_serializer.config.auto_preload_excluded_methods).to eq %i[current_object __getobj__]
    end
  end

  describe ".inherited" do
    let(:parent) { serializer }

    it "inherits Presenter class" do
      child = Class.new(parent)
      expect(parent::Presenter).to be child::Presenter.superclass
    end
  end

  it "adds presenter methods used in block after first serialization" do
    serializer::Presenter.class_exec do
      def rev
      end
    end
    serializer.attribute(:length) { |obj| obj.size }

    expect(serializer::Presenter.instance_methods).not_to include(:size)
    serializer.new.to_h("")
    expect(serializer::Presenter.instance_methods).to include(:size)
  end

  it "allows to use custom methods defined directly in Presenter class" do
    serializer::Presenter.class_exec do
      def rev
        reverse
      end
    end

    serializer.attribute(:rev) { |obj| obj.rev }
    result = serializer.new.to_h("123")
    expect(result).to eq({rev: "321"})
  end

  it "works for arrays" do
    serializer.attribute :value
    serializer::Presenter.class_exec do
      def value
        __getobj__
      end
    end

    result = serializer.new.to_h([123, 234])
    expect(result).to eq([{value: 123}, {value: 234}])
  end

  it "makes __ctx__ private" do
    expect(serializer::Presenter.private_method_defined?(:__ctx__)).to be true
  end

  it "exposes context inside Presenter via __ctx__" do
    serializer.attribute(:greeting) { |obj| obj.greeting }
    serializer::Presenter.class_exec do
      def greeting
        "Hello, #{__ctx__[:name]}!"
      end
    end

    result = serializer.new.to_h("ignored", context: {name: "Alice"})
    expect(result).to eq({greeting: "Hello, Alice!"})
  end

  it "passes presenters to batch loaders, keyed consistently with attribute values" do
    received = nil
    serializer.attribute(:id)
    serializer.attribute(:score, batch: proc { |objects|
      received = objects
      objects.to_h { |object| [object.id, object.id * 10] }
    })
    # Presenter overrides #id, so the batch key must come from the presenter too,
    # or the loaded value would not be found.
    serializer::Presenter.class_exec do
      def id
        __getobj__.id + 100
      end
    end

    object = Struct.new(:id)
    result = serializer.to_h([object.new(1), object.new(2)])

    expect(received).to all be_a(SimpleDelegator)
    expect(result).to eq [{id: 101, score: 1010}, {id: 102, score: 1020}]
  end

  it "works in nested relation" do
    struct = Struct.new(:nested).new("123")

    current_serializer = serializer
    current_serializer.attribute(:rev)
    current_serializer::Presenter.class_exec do
      def rev
        reverse
      end
    end

    base_serializer = Class.new(Serega) do
      attribute :nested, serializer: current_serializer
    end

    result = base_serializer.new.to_h(struct)
    expect(result).to eq({nested: {rev: "321"}})
  end

  it "does not auto-preload the :__getobj__ unwrap method" do
    # objects are wrapped (and __getobj__ is meaningful) only when the
    # Presenter is customized
    serializer::Presenter.class_exec do
      def rating
      end
    end

    nested_serializer = Class.new(Serega) { attribute :id }
    serializer.config.auto_preload = true
    attribute = serializer.attribute :statistics, serializer: nested_serializer, method: :__getobj__

    expect(attribute.preloads).to be_nil
    expect(serializer.to_h(double(id: 1))).to eq(statistics: {id: 1})
  end

  describe "skipping wrapping when Presenter has no custom methods" do
    it "does not wrap objects in Presenter" do
      received = nil
      serializer.attribute(:name) { |obj|
        received = obj
        obj.to_s
      }

      serializer.new.to_h("raw object")

      expect(received).to eq "raw object"
      expect(received).not_to be_a(SimpleDelegator)
    end

    it "wraps objects when Presenter is reopened after first serialization" do
      received = nil
      serializer.attribute(:name) { |obj|
        received = obj
        obj.to_s
      }

      serializer.new.to_h("raw object")
      expect(received).not_to be_a(SimpleDelegator)

      serializer::Presenter.class_exec do
        def to_s
          "presented"
        end
      end

      result = serializer.new.to_h("raw object")
      expect(received).to be_a(SimpleDelegator)
      expect(result).to eq({name: "presented"})
    end
  end

  describe ".custom_presenter?" do
    it "returns false when Presenter was not modified" do
      expect(serializer.custom_presenter?).to be false
    end

    it "returns true when a method was defined on Presenter" do
      serializer::Presenter.class_exec do
        def name
        end
      end

      expect(serializer.custom_presenter?).to be true
    end

    it "returns true when a module was included into Presenter" do
      presenter_methods = Module.new do
        def name
        end
      end
      serializer::Presenter.include(presenter_methods)

      expect(serializer.custom_presenter?).to be true
    end

    it "returns true when a module was prepended to Presenter" do
      presenter_methods = Module.new do
        def name
        end
      end
      serializer::Presenter.prepend(presenter_methods)

      expect(serializer.custom_presenter?).to be true
    end

    it "returns true for a child of a serializer with modified Presenter" do
      serializer::Presenter.class_exec do
        def name
        end
      end

      child = Class.new(serializer)
      expect(child.custom_presenter?).to be true
    end

    it "stays false on the parent when only the child Presenter is modified" do
      child = Class.new(serializer)
      child::Presenter.class_exec do
        def name
        end
      end

      expect(child.custom_presenter?).to be true
      expect(serializer.custom_presenter?).to be false
    end
  end
end
