# frozen_string_literal: true

RSpec.describe Serega::SeregaPresenter do
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

  context "with a presenter method and a value block that calls another method" do
    let(:serializer) do
      Class.new(Serega) do
        attribute(:length, value: proc { |obj| obj.size })

        presenter do
          def rev
          end
        end

        freeze
      end
    end

    it "defines a real delegator method after the first method_missing hit" do
      expect(serializer.presenter.instance_methods).not_to include(:size)
      serializer.new.to_h("")
      expect(serializer.presenter.instance_methods).to include(:size)
    end
  end

  context "with two serializers with presenters" do
    let(:report_serializer) do
      Class.new(Serega) do
        attribute :format
        presenter { define_method(:unused) {} }
        freeze
      end
    end

    let(:price_serializer) do
      Class.new(Serega) do
        attribute :label

        presenter do
          def label
            format("%.2f", __getobj__)
          end
        end

        freeze
      end
    end

    it "keeps delegators of each serializer presenter separate" do
      report_serializer.to_h(Struct.new(:format).new("pdf"))

      expect(price_serializer.presenter.method_defined?(:format)).to be false
      expect(price_serializer.to_h(1.5)).to eq(label: "1.50")
    end
  end

  context "with a value block that calls a method with keyword arguments" do
    let(:serializer) do
      Class.new(Serega) do
        attribute :greeting, value: proc { |record| record.greet("Hi", punctuation: "!") }
        presenter { define_method(:unused) {} }
        freeze
      end
    end

    let(:record_class) do
      Class.new do
        def greet(greeting, punctuation: ".") = "#{greeting}#{punctuation}"
      end
    end

    it "delegates keyword arguments" do
      expect(serializer.to_h(record_class.new)).to eq(greeting: "Hi!")
    end
  end

  context "with a value block that calls methods with any names and arguments" do
    let(:serializer) do
      Class.new(Serega) do
        attribute :result, value: proc { |record|
          record.name = "Kate"
          [record[:key], record.greet("Hi", punctuation: "!") { "?" }, record.name, record.public_send(:"full-name", " ")]
        }
        presenter { define_method(:unused) {} }
        freeze
      end
    end

    let(:record_class) do
      Class.new do
        attr_accessor :name

        def [](key) = "#{key}!"

        def greet(greeting, punctuation: ".") = "#{greeting}, #{name}#{punctuation}#{yield}"

        define_method(:"full-name") { |separator| "Kate#{separator}Nash" }
      end
    end

    it "delegates methods with any names and arguments" do
      2.times do
        expect(serializer.to_h(record_class.new)).to eq(result: ["key!", "Hi, Kate!?", "Kate", "Kate Nash"])
      end
    end
  end

  context "with a presenter method that calls a private Kernel method" do
    let(:serializer) do
      Class.new(Serega) do
        attribute :formatted

        presenter do
          def formatted
            format("%05d", __getobj__)
          end
        end

        freeze
      end
    end

    it "calls private Kernel methods on the presenter" do
      2.times { expect(serializer.to_h(42)).to eq(formatted: "00042") }
    end
  end

  context "with a presenter method that calls super" do
    let(:serializer) do
      Class.new(Serega) do
        attribute :upcase_name

        presenter do
          def upcase_name
            super.upcase
          end
        end

        freeze
      end
    end

    it "keeps presenter methods that call super" do
      user = Struct.new(:upcase_name).new("Kate")

      2.times { expect(serializer.to_h(user)).to eq(upcase_name: "KATE") }
    end
  end

  context "with a custom presenter method" do
    let(:serializer) do
      Class.new(Serega) do
        attribute(:rev, value: proc { |obj| obj.rev })

        presenter do
          def rev
            reverse
          end
        end

        freeze
      end
    end

    it "allows to use custom presenter methods" do
      expect(serializer.new.to_h("123")).to eq({rev: "321"})
    end
  end

  context "with a presenter method that returns the wrapped object" do
    let(:serializer) do
      Class.new(Serega) do
        attribute :value

        presenter do
          def value
            __getobj__
          end
        end

        freeze
      end
    end

    it "works for arrays" do
      expect(serializer.new.to_h([123, 234])).to eq([{value: 123}, {value: 234}])
    end
  end

  it "makes __ctx__ private" do
    expect(described_class.private_method_defined?(:__ctx__)).to be true
  end

  context "with a base serializer and a block-defined nested serializer" do
    let(:base) { Class.new(Serega) }

    let(:serializer) do
      base_serializer = base

      Class.new(base) do
        config.base_serializer = base_serializer

        presenter do
          def full_name
            "current serializer presenter method"
          end
        end

        attribute(:profile, method: :itself) { attribute :bio }
      end
    end

    it "gives a block-defined nested serializer the base serializer Presenter without current presenter methods" do
      nested = serializer.attributes[:profile].serializer

      expect(serializer.presenter.new("Kate", nil).full_name).to eq "current serializer presenter method"
      expect(nested.presenter).to be_nil
    end
  end

  context "with presenter methods in a block-defined nested serializer" do
    let(:serializer) do
      Class.new(Serega) do
        config.base_serializer = Serega

        attribute(:profile, method: :itself) do
          attribute :bio

          presenter do
            def bio
              "bio of #{__getobj__}"
            end
          end
        end

        freeze
      end
    end

    it "wraps nested objects with the nested serializer SeregaPresenter" do
      expect(serializer.new.to_h("Kate")).to eq(profile: {bio: "bio of Kate"})
    end
  end

  context "with a presenter method that reads the context" do
    let(:serializer) do
      Class.new(Serega) do
        attribute(:greeting, value: proc { |obj| obj.greeting })

        presenter do
          def greeting
            "Hello, #{__ctx__[:name]}!"
          end
        end

        freeze
      end
    end

    it "exposes context inside SeregaPresenter via __ctx__" do
      expect(serializer.new.to_h("ignored", context: {name: "Alice"})).to eq({greeting: "Hello, Alice!"})
    end
  end

  context "with a batch loader and a presenter method that overrides the batch key" do
    let(:received) { [] }

    let(:serializer) do
      received_objects = received

      Class.new(Serega) do
        attribute(:id)
        attribute(:score, batch: proc { |objects|
          received_objects.concat(objects)
          objects.to_h { |object| [object.id, object.id * 10] }
        })

        # The presenter overrides #id, so the batch key must come from the presenter too,
        # or the loaded value would not be found.
        presenter do
          def id
            __getobj__.id + 100
          end
        end

        freeze
      end
    end

    it "passes presenters to batch loaders, keyed consistently with attribute values" do
      object = Struct.new(:id)
      result = serializer.to_h([object.new(1), object.new(2)])

      expect(received).to all be_a(SimpleDelegator)
      expect(result).to eq [{id: 101, score: 1010}, {id: 102, score: 1020}]
    end
  end

  context "with a presenter in a relation serializer" do
    let(:nested_serializer) do
      Class.new(Serega) do
        attribute(:rev)

        presenter do
          def rev
            reverse
          end
        end

        freeze
      end
    end

    let(:serializer) do
      nested = nested_serializer

      Class.new(Serega) do
        attribute :nested, serializer: nested
        freeze
      end
    end

    it "works in nested relation" do
      struct = Struct.new(:nested).new("123")

      expect(serializer.new.to_h(struct)).to eq({nested: {rev: "321"}})
    end
  end

  context "with auto_preload and a relation read with :__getobj__" do
    # objects are wrapped (and __getobj__ is meaningful) only when the
    # presenter is customized
    let(:nested_serializer) { Class.new(Serega) { attribute :id }.freeze }

    let(:serializer) do
      nested = nested_serializer

      Class.new(Serega) do
        config.auto_preload = true
        attribute :statistics, serializer: nested, method: :__getobj__

        presenter do
          def rating
          end
        end

        freeze
      end
    end

    it "does not auto-preload the :__getobj__ unwrap method" do
      expect(serializer.attributes[:statistics].preloads).to be_nil
      expect(serializer.to_h(double(id: 1))).to eq(statistics: {id: 1})
    end
  end

  describe "skipping wrapping when SeregaPresenter has no custom methods" do
    let(:received) { [] }

    let(:serializer) do
      received_objects = received

      Class.new(Serega) do
        attribute(:name, value: proc { |obj|
          received_objects << obj
          obj.to_s
        })

        freeze
      end
    end

    it "does not wrap objects in SeregaPresenter" do
      serializer.new.to_h("raw object")

      expect(received).to eq ["raw object"]
      expect(received.first).not_to be_a(SimpleDelegator)
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
          freeze
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

          freeze
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

          freeze
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
    let(:serializer) { Class.new(Serega) }

    context "with a presenter method that calls other methods of the object" do
      let(:serializer) do
        Class.new(Serega) do
          attribute :full_name

          presenter do
            def full_name
              "#{first_name} #{last_name}"
            end
          end

          freeze
        end
      end

      it "defines presenter methods evaluated inside the SeregaPresenter class" do
        user = double(first_name: "Kate", last_name: "Nash")
        expect(serializer.to_h(user)).to eq(full_name: "Kate Nash")
      end
    end

    context "with multiple presenter blocks" do
      let(:serializer) do
        Class.new(Serega) do
          attribute :first_name
          attribute :last_name

          presenter do
            def first_name
              "Kate"
            end
          end

          presenter do
            def last_name
              "Nash"
            end
          end

          freeze
        end
      end

      it "accumulates methods from multiple blocks" do
        expect(serializer.to_h("user")).to eq(first_name: "Kate", last_name: "Nash")
      end
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

    context "with a presenter inside an attribute block" do
      let(:serializer) do
        Class.new(Serega) do
          config.base_serializer = Serega

          attribute(:account, method: :itself) do
            attribute :login

            presenter do
              def login
                "@#{__getobj__}"
              end
            end
          end

          freeze
        end
      end

      it "can be used inside an attribute block" do
        expect(serializer.to_h("kate")).to eq(account: {login: "@kate"})
      end
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

    context "with a presenter block that includes a module" do
      let(:serializer) do
        presenter_methods = Module.new do
          def name
            "included"
          end
        end

        Class.new(Serega) do
          attribute :name
          presenter { include presenter_methods }
          freeze
        end
      end

      it "evaluates the block so a module can be included" do
        expect(serializer.to_h("user")).to eq(name: "included")
      end
    end

    context "with a presenter block that prepends a module" do
      let(:serializer) do
        presenter_methods = Module.new do
          def name
            "prepended"
          end
        end

        Class.new(Serega) do
          attribute :name
          presenter { prepend presenter_methods }
          freeze
        end
      end

      it "evaluates the block so a module can be prepended" do
        expect(serializer.to_h("user")).to eq(name: "prepended")
      end
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
    let(:serializer) do
      records = {"1" => double(first_name: "Ann")}

      Class.new(Serega) do
        prepare_initial_objects { |ids| ids.map { |id| records[id] } }
        attribute :first_name

        presenter do
          def first_name
            super.upcase
          end
        end

        freeze
      end
    end

    it "wraps prepared objects in the SeregaPresenter" do
      expect(serializer.to_h(["1"])).to eq [{first_name: "ANN"}]
    end
  end
end
