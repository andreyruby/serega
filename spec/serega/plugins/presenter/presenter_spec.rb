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
    serializer.attribute(:length, value: proc { |obj| obj.size })

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

    serializer.attribute(:rev, value: proc { |obj| obj.rev })
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

  it "gives a block-defined nested serializer the base serializer Presenter without current presenter methods" do
    base = Class.new(Serega) { plugin :presenter }
    current_serializer = Class.new(base)
    current_serializer.config.base_serializer = base
    current_serializer::Presenter.class_exec do
      def full_name
        "current serializer presenter method"
      end
    end

    current_serializer.attribute(:profile, method: :itself) { attribute :bio }
    nested = current_serializer.attributes[:profile].serializer

    expect(current_serializer::Presenter.new("Kate", nil).full_name).to eq "current serializer presenter method"
    expect(nested.plugin_used?(:presenter)).to be true
    expect(nested::Presenter.method_defined?(:full_name)).to be false
  end

  it "wraps nested objects with the nested serializer Presenter" do
    serializer.config.base_serializer = serializer
    serializer.attribute(:profile, method: :itself) { attribute :bio }
    nested = serializer.attributes[:profile].serializer
    nested::Presenter.class_exec do
      def bio
        "bio of #{__getobj__}"
      end
    end

    expect(serializer.new.to_h("Kate")).to eq(profile: {bio: "bio of Kate"})
  end

  it "exposes context inside Presenter via __ctx__" do
    serializer.attribute(:greeting, value: proc { |obj| obj.greeting })
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

    result = base_serializer.new.to_h(struct, many: false)
    expect(result).to eq({nested: {rev: "321"}})
  end
end
