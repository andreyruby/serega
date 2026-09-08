# frozen_string_literal: true

RSpec.describe Serega::SeregaPresenter do
  let(:serializer) { Class.new(Serega) }

  describe ".inherited" do
    let(:parent) do
      Class.new(Serega) do
        presenter do
          def name
          end
        end
      end
    end

    it "builds the child presenter by replaying the parent blocks" do
      child = Class.new(parent)

      expect(child.presenter).not_to be parent.presenter
      expect(child.presenter.method_defined?(:name)).to be true
    end

    it "copies the parent blocks once per generation" do
      child = Class.new(parent)
      child.presenter do
        def other
        end
      end
      grandchild = Class.new(child)

      expect(grandchild.presenter_blocks.size).to eq 2
      expect(grandchild.presenter.method_defined?(:name)).to be true
      expect(grandchild.presenter.method_defined?(:other)).to be true
    end
  end

  it "defines a real delegator method after the first method_missing hit" do
    serializer.presenter do
      def rev
      end
    end
    serializer.attribute(:length, value: proc { |obj| obj.size })

    expect(serializer.presenter.instance_methods).not_to include(:size)
    serializer.new.to_h("")
    expect(serializer.presenter.instance_methods).to include(:size)
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
    expect(described_class.private_method_defined?(:__ctx__)).to be true
  end

  it "gives a block-defined nested serializer the base serializer Presenter without current presenter methods" do
    base = Class.new(Serega)
    current_serializer = Class.new(base)
    current_serializer.config.base_serializer = base
    current_serializer.presenter do
      def full_name
        "current serializer presenter method"
      end
    end

    current_serializer.attribute(:profile, method: :itself) { attribute :bio }
    nested = current_serializer.attributes[:profile].serializer

    expect(current_serializer.presenter.new("Kate", nil).full_name).to eq "current serializer presenter method"
    expect(nested.presenter).to be_nil
  end

  it "wraps nested objects with the nested serializer SeregaPresenter" do
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

  it "exposes context inside SeregaPresenter via __ctx__" do
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
    # The presenter overrides #id, so the batch key must come from the presenter too,
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
    # presenter is customized
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

  describe "skipping wrapping when SeregaPresenter has no custom methods" do
    it "does not wrap objects in SeregaPresenter" do
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

  describe "unwrapping objects before preloads" do
    subject(:serialize) { serializer.to_h(["raw object"]) }

    let(:preloaded) { [] }

    let(:app_serializer) do
      records = preloaded
      Class.new(Serega) do
        preload_with { |objects, _preloads| records.concat(objects) }
      end
    end

    context "when SeregaPresenter has no custom methods" do
      let(:serializer) do
        Class.new(app_serializer) do
          attribute :name, preload: :assoc, value: proc { |obj| obj.to_s }
        end
      end

      it "passes objects to the preload handler unchanged" do
        serialize

        expect(preloaded).to eq ["raw object"]
        expect(preloaded.first).not_to be_a SimpleDelegator
      end
    end

    context "when the serializer that registers the handler has presenter methods" do
      let(:serializer) do
        records = preloaded
        Class.new(Serega) do
          preload_with { |objects, _preloads| records.concat(objects) }
          attribute :name, preload: :assoc

          presenter do
            def name
              "presented"
            end
          end
        end
      end

      it "passes underlying objects to the preload handler" do
        serialize

        expect(preloaded).to eq ["raw object"]
        expect(preloaded.first).not_to be_a SimpleDelegator
      end
    end

    context "when a subclass has presenter methods" do
      let(:serializer) do
        Class.new(app_serializer) do
          attribute :name, preload: :assoc

          presenter do
            def name
              "presented"
            end
          end
        end
      end

      it "passes underlying objects to the preload handler" do
        serialize

        expect(preloaded).to eq ["raw object"]
        expect(preloaded.first).not_to be_a SimpleDelegator
      end
    end
  end

  describe ".presenter" do
    it "defines presenter methods evaluated inside the SeregaPresenter class" do
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

    it "does not leak methods defined in a child serializer to the parent" do
      child = Class.new(serializer)
      child.presenter do
        def name
        end
      end

      expect(child.presenter.method_defined?(:name)).to be true
      expect(serializer.presenter).to be_nil
    end

    it "can be used inside an attribute block" do
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

    it "returns nil when no block was given" do
      expect(serializer.presenter).to be_nil
    end

    it "returns the presenter class when a block was given" do
      presenter_class = serializer.presenter do
        def name
        end
      end

      expect(presenter_class).to be < described_class
      expect(serializer.presenter).to be presenter_class
    end

    it "evaluates the block so a module can be included" do
      presenter_methods = Module.new do
        def name
          "included"
        end
      end
      serializer.attribute :name
      serializer.presenter { include presenter_methods }

      expect(serializer.to_h("user")).to eq(name: "included")
    end

    it "evaluates the block so a module can be prepended" do
      presenter_methods = Module.new do
        def name
          "prepended"
        end
      end
      serializer.attribute :name
      serializer.presenter { prepend presenter_methods }

      expect(serializer.to_h("user")).to eq(name: "prepended")
    end

    it "returns a presenter with the parent methods for a child that defines none" do
      serializer.presenter do
        def name
        end
      end

      child = Class.new(serializer)
      expect(child.presenter.method_defined?(:name)).to be true
    end

    it "does not reach an existing child when the parent defines a presenter later" do
      child = Class.new(serializer)
      serializer.presenter do
        def name
        end
      end

      expect(child.presenter).to be_nil
    end

    it "stays nil on the parent when only the child defines a presenter" do
      child = Class.new(serializer)
      child.presenter do
        def name
        end
      end

      expect(child.presenter).to be_a Class
      expect(serializer.presenter).to be_nil
    end
  end

  describe "prepare_initial_objects" do
    it "wraps prepared objects in the SeregaPresenter" do
      records = {"1" => double(first_name: "Ann")}
      user_serializer = Class.new(Serega) do
        prepare_initial_objects { |ids| ids.map { |id| records[id] } }
        attribute :first_name
        presenter do
          def first_name
            super.upcase
          end
        end
      end

      expect(user_serializer.to_h(["1"])).to eq [{first_name: "ANN"}]
    end
  end
end
