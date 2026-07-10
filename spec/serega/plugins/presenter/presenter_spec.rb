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
    serializer.presenter do
      def rev
      end
    end
    serializer.attribute(:length, value: proc { |obj| obj.size })

    expect(serializer::Presenter.instance_methods).not_to include(:size)
    serializer.new.to_h("")
    expect(serializer::Presenter.instance_methods).to include(:size)
  end

  it "allows to use custom presenter methods" do
    serializer.presenter do
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
    serializer.presenter do
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
    current_serializer.presenter do
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
    nested.presenter do
      def bio
        "bio of #{__getobj__}"
      end
    end

    expect(serializer.new.to_h("Kate")).to eq(profile: {bio: "bio of Kate"})
  end

  it "exposes context inside Presenter via __ctx__" do
    serializer.attribute(:greeting, value: proc { |obj| obj.greeting })
    serializer.presenter do
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
    serializer.presenter do
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
    current_serializer.presenter do
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
    serializer.presenter do
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
      value = proc { |obj|
        received = obj
        obj.to_s
      }
      serializer.attribute(:name, value: value)

      serializer.new.to_h("raw object")

      expect(received).to eq "raw object"
      expect(received).not_to be_a(SimpleDelegator)
    end

    it "wraps objects when presenter methods are added after first serialization" do
      received = nil
      value = proc { |obj|
        received = obj
        obj.to_s
      }
      serializer.attribute(:name, value: value)

      serializer.new.to_h("raw object")
      expect(received).not_to be_a(SimpleDelegator)

      serializer.presenter do
        def to_s
          "presented"
        end
      end

      result = serializer.new.to_h("raw object")
      expect(received).to be_a(SimpleDelegator)
      expect(result).to eq({name: "presented"})
    end
  end

  describe ".presenter" do
    it "defines presenter methods evaluated inside the Presenter class" do
      serializer.attribute :full_name
      serializer.presenter do
        def full_name
          "#{first_name} #{last_name}"
        end
      end

      user = double(first_name: "Kate", last_name: "Nash")
      expect(serializer.to_h(user)).to eq(full_name: "Kate Nash")
    end

    it "accumulates methods from multiple blocks" do
      serializer.attribute :first_name
      serializer.attribute :last_name
      serializer.presenter do
        def first_name
          "Kate"
        end
      end
      serializer.presenter do
        def last_name
          "Nash"
        end
      end

      expect(serializer.to_h("user")).to eq(first_name: "Kate", last_name: "Nash")
    end

    it "marks the presenter as customized" do
      serializer.presenter do
        def name
        end
      end

      expect(serializer.custom_presenter?).to be true
    end

    it "does not leak methods defined in a child serializer to the parent" do
      child = Class.new(serializer)
      child.presenter do
        def name
        end
      end

      expect(child::Presenter.method_defined?(:name)).to be true
      expect(serializer::Presenter.method_defined?(:name)).to be false
    end

    it "can be used inside an attribute block when base serializer has the plugin" do
      serializer.config.base_serializer = serializer
      serializer.attribute(:account, method: :itself) do
        attribute :login

        presenter do
          def login
            "@#{__getobj__}"
          end
        end
      end

      expect(serializer.to_h("kate")).to eq(account: {login: "@kate"})
    end

    it "raises an error when called without a block" do
      expect { serializer.presenter }.to raise_error Serega::SeregaError,
        "Provide a block with presenter methods: `presenter do ... end`"
    end
  end

  describe ".custom_presenter?" do
    it "returns false when Presenter was not modified" do
      expect(serializer.custom_presenter?).to be false
    end

    it "returns true when a presenter method was defined" do
      serializer.presenter do
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
      serializer.presenter do
        def name
        end
      end

      child = Class.new(serializer)
      expect(child.custom_presenter?).to be true
    end

    it "stays false on the parent when only the child Presenter is modified" do
      child = Class.new(serializer)
      child.presenter do
        def name
        end
      end

      expect(child.custom_presenter?).to be true
      expect(serializer.custom_presenter?).to be false
    end
  end
end
