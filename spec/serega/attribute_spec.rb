# frozen_string_literal: true

RSpec.describe Serega::SeregaAttribute do
  let(:serializer_class) { Class.new(Serega) }
  let(:attribute_class) { serializer_class::SeregaAttribute }

  describe ".initialize" do
    it "validates provided params" do
      serializer_class.config.base_serializer = Serega
      name = :current_name
      opts = {foo: :bar}
      block = proc { attribute :nested_name }
      checker = instance_double(serializer_class::CheckAttributeParams, validate: nil)
      allow(serializer_class::CheckAttributeParams).to receive(:new).with(name, opts, block).and_return(checker)

      attribute_class.new(name: :current_name, opts: opts, block: block)

      expect(checker).to have_received(:validate)
    end

    it "duplicates provided options" do
      opts = {serializer: "foo"}
      attr_opts = attribute_class.new(name: :name, opts: opts).initials[:opts]
      expect(opts).to eql attr_opts
      expect(attr_opts).not_to be(opts)
    end

    it "saves provided block" do
      serializer_class.config.base_serializer = Serega
      expect(attribute_class.new(name: :name).initials[:block]).to be_nil
      block = proc { attribute :nested_name }
      expect(attribute_class.new(name: :name, block: block).initials[:block]).to eq block
    end

    it "sets attribute instance variables using normalizer" do
      normalizer = instance_double(
        serializer_class::SeregaAttributeNormalizer,
        name: nil,
        many: nil,
        default: nil,
        hide: nil,
        serializer: nil,
        batch_loaders: nil,
        method: nil,
        value_block: nil,
        value_block_signature: nil,
        preloads: nil
      )

      initials = {name: :name, opts: {}, block: nil}
      allow(serializer_class::SeregaAttributeNormalizer).to receive(:new).with(initials).and_return(normalizer)
      attribute = attribute_class.new(**initials)

      expect(attribute.instance_variables)
        .to include(
          :@name,
          :@default,
          :@value_block,
          :@value_block_signature,
          :@batch_loaders,
          :@many,
          :@hide,
          :@serializer,
          :@preloads
        )
    end
  end

  describe "#relation?" do
    it "returns true if serializer option provided" do
      expect(attribute_class.new(name: :name).relation?).to be false
      expect(attribute_class.new(name: :name, opts: {serializer: serializer_class}).relation?).to be true
    end
  end

  describe "#serializer" do
    let(:serializer) { Class.new(Serega) }
    let(:serializer_as_proc) { proc { serializer } }

    it "returns provided :serializer option" do
      expect(attribute_class.new(name: :name, opts: {serializer: serializer}).serializer).to eq serializer
    end

    it "extracts provided :serializer from Proc" do
      expect(attribute_class.new(name: :name, opts: {serializer: serializer_as_proc}).serializer).to eq serializer
    end

    it "extracts provided :serializer from String" do
      Object.const_set(:AAA, serializer)
      expect(attribute_class.new(name: :name, opts: {serializer: "AAA"}).serializer).to eq serializer
    end
  end

  describe "#value" do
    context "with no args" do
      it "gets value" do
        value = lambda { "NAME" }
        attribute = attribute_class.new(name: :name, opts: {value: value})
        expect(attribute.value(nil, nil)).to eq "NAME"
      end
    end

    context "with 1 arg" do
      it "gets value" do
        obj = double(name: "NAME")
        value = proc { |obj| obj.name }
        attribute = attribute_class.new(name: :name, opts: {value: value})
        expect(attribute.value(obj, nil)).to eq "NAME"
      end
    end

    context "with 2 args" do
      it "gets value" do
        obj = double(name: "NAME")
        ctx = {foo: "CTX"}
        value = lambda { |obj, ctx| [obj.name, ctx[:foo]] }
        attribute = attribute_class.new(name: :name, opts: {value: value})
        expect(attribute.value(obj, ctx)).to eq ["NAME", "CTX"]
      end
    end

    context "with 1 arg and ctx keyword" do
      it "gets value" do
        obj = double(name: "NAME")
        ctx = {foo: "CTX"}
        value = lambda { |obj, ctx:| [obj.name, ctx[:foo]] }
        attribute = attribute_class.new(name: :name, opts: {value: value})
        expect(attribute.value(obj, ctx)).to eq ["NAME", "CTX"]
      end
    end

    context "with 1 arg and batches keyword" do
      it "gets value" do
        obj = double(name: "NAME")
        ctx = nil
        batches = {foo: "LAZY"}
        value = lambda { |obj, batches:| [obj.name, batches[:foo]] }
        attribute = attribute_class.new(name: :name, opts: {value: value})
        expect(attribute.value(obj, ctx, batches: batches)).to eq ["NAME", "LAZY"]
      end
    end

    context "with 1 arg, ctx and batches keywords" do
      it "gets value" do
        obj = double(name: "NAME")
        ctx = {foo: "CTX"}
        batches = {foo: "LAZY"}
        value = lambda { |obj, ctx:, batches:| [obj.name, ctx[:foo], batches[:foo]] }
        attribute = attribute_class.new(name: :name, opts: {value: value})
        expect(attribute.value(obj, ctx, batches: batches)).to eq ["NAME", "CTX", "LAZY"]
      end
    end

    context "with 2 args, ctx and batches keywords" do
      it "gets value" do
        obj = double(name: "NAME")
        ctx = {foo: "CTX"}
        batches = {foo: "LAZY"}
        value = lambda { |obj, _context, ctx:, batches:| [obj.name, ctx[:foo], batches[:foo]] }
        attribute = attribute_class.new(name: :name, opts: {value: value})
        expect(attribute.value(obj, ctx, batches: batches)).to eq ["NAME", "CTX", "LAZY"]
      end
    end

    context "when returning value is nil" do
      it "returns default" do
        obj = nil
        ctx = {foo: "CTX"}
        value = lambda { |obj| obj }
        attribute = attribute_class.new(name: :name, opts: {value: value, default: 42})
        expect(attribute.value(obj, ctx)).to eq 42
      end
    end

    it "works when attribute has name with `-` sign" do
      obj = double("-foo": "-bar")
      attribute = attribute_class.new(name: :"-foo")
      expect(attribute.value(obj, nil)).to eq "-bar"
    end
  end

  describe "#visible?" do
    def default
      {except: {}, only: {}, with: {}}
    end

    def except(key)
      {except: {key => {}}, only: {}, with: {}}
    end

    def only(key)
      {except: {}, only: {key => {}}, with: {}}
    end

    def with(key)
      {except: {}, only: {}, with: {key => {}}}
    end

    it "returns by default true when attribute is not hidden" do
      expect(attribute_class.new(name: :name).visible?(**default)).to be true
    end

    it "returns by default false when attribute is hidden" do
      expect(attribute_class.new(name: :name, opts: {hide: true}).visible?(**default)).to be false
    end

    it "returns false when attribute is hidden via :only parameter" do
      expect(attribute_class.new(name: :name).visible?(**only(:other))).to be false
    end

    it "returns true when attribute is shown via :only parameter" do
      expect(attribute_class.new(name: :name, opts: {hide: true}).visible?(**only(:name))).to be true
    end

    it "returns true when attribute is shown via :with parameter" do
      expect(attribute_class.new(name: :name, opts: {hide: true}).visible?(**with(:name))).to be true
    end

    it "returns false when attribute is hidden via :except parameter" do
      expect(attribute_class.new(name: :name).visible?(**except(:name))).to be false
    end

    it "skips :except parameter if it has nested keys" do
      args = except(:name)
      args[:except][:name] = {foo: {}}

      expect(attribute_class.new(name: :name).visible?(**args)).to be true
    end
  end
end
