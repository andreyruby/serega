# frozen_string_literal: true

load_plugin_code :presenter

RSpec.describe Serega::SeregaPlugins::Presenter do
  let(:serializer) { Class.new(Serega) { plugin :presenter } }

  describe "loading" do
    it "adds serializer::Presenter class" do
      expect(serializer::Presenter).to be_a Class
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

    result = base_serializer.new.to_h(struct, many: false)
    expect(result).to eq({nested: {rev: "321"}})
  end
end
