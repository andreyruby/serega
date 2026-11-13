# frozen_string_literal: true

RSpec.describe Serega::SeregaAttribute do
  let(:serializer_class) { Class.new(Serega) }

  describe ".initialize" do
    it "validates provided params" do
      serializer_class.config.base_serializer = Serega
      name = :current_name
      opts = {foo: :bar}
      block = proc { attribute :nested_name }
      checker = instance_double(Serega::SeregaValidations::CheckAttributeParams, validate: nil)
      allow(Serega::SeregaValidations::CheckAttributeParams).to receive(:new).and_call_original # attributes of the nested serializer
      allow(Serega::SeregaValidations::CheckAttributeParams)
        .to receive(:new).with(serializer_class, name, opts, block).and_return(checker)

      described_class.new(serializer_class, name: :current_name, opts: opts, block: block)

      expect(checker).to have_received(:validate)
    end

    it "duplicates provided options" do
      opts = {serializer: "foo"}
      attr_opts = described_class.new(serializer_class, name: :name, opts: opts).initials[:opts]
      expect(opts).to eql attr_opts
      expect(attr_opts).not_to be(opts)
    end

    it "saves provided block" do
      serializer_class.config.base_serializer = Serega
      expect(described_class.new(serializer_class, name: :name).initials[:block]).to be_nil
      block = proc { attribute :nested_name }
      expect(described_class.new(serializer_class, name: :name, block: block).initials[:block]).to eq block
    end

    it "sets attribute instance variables using normalizer" do
      normalizer = instance_double(
        Serega::SeregaAttributeNormalizer,
        name: nil,
        many: nil,
        default: nil,
        hide: nil,
        serializer: nil,
        batch_loaders: nil,
        inline_batch_loader: nil,
        method: nil,
        value_block: nil,
        value_block_signature: nil,
        preloads: nil,
        conditions: nil,
        formatter: nil
      )

      initials = {name: :name, opts: {}, block: nil, location: "app/serializers/user_serializer.rb:3"}
      allow(Serega::SeregaAttributeNormalizer).to receive(:new).with(serializer_class, initials).and_return(normalizer)
      attribute = described_class.new(serializer_class, **initials)

      expect(attribute.instance_variables)
        .to include(
          :@name,
          :@default,
          :@value_block,
          :@value_block_signature,
          :@batch_loaders,
          :@inline_batch_loader,
          :@many,
          :@hide,
          :@serializer,
          :@preloads,
          :@conditions,
          :@formatter
        )
    end
  end

  describe "stored values" do
    subject(:values) do
      described_class.new(serializer_class, name: :full_name, opts: opts)
      serializer_class::SeregaAttributeValues
    end

    let(:opts) { {const: "Ann"} }

    it "stores the :const value" do
      expect(values::CONSTANTS).to eq(full_name: "Ann")
    end

    context "with the :default option" do
      let(:opts) { {default: "Nobody"} }

      it "stores the default value" do
        expect(values::DEFAULTS).to eq(full_name: "Nobody")
      end
    end

    context "with the :value and :default options" do
      let(:opts) { {value: proc { |user| user.full_name }, default: "Nobody"} }

      it "stores the default value" do
        expect(values::DEFAULTS).to eq(full_name: "Nobody")
      end
    end

    context "with a method formatter with arguments" do
      let(:opts) { {format: [:round, 2]} }

      it "stores the formatter arguments" do
        expect(values::FORMATTER_ARGS).to eq(full_name: [2])
      end
    end

    context "with a callable formatter" do
      let(:formatter) { proc { |name| name.upcase } }
      let(:opts) { {format: formatter} }

      it "stores the formatter callable" do
        expect(values::FORMATTERS).to eq(full_name: formatter)
      end
    end

    context "with the :const option in a subclass" do
      subject(:values) do
        described_class.new(serializer_class, name: :full_name, opts: opts)
        subclass.attribute :full_name, const: "Bob"
        serializer_class::SeregaAttributeValues
      end

      let(:subclass) { Class.new(serializer_class) }

      it "keeps the constant of the parent" do
        expect(values::CONSTANTS).to eq(full_name: "Ann")
        expect(subclass::SeregaAttributeValues::CONSTANTS).to eq(full_name: "Bob")
      end
    end
  end

  describe "#relation?" do
    it "returns true if serializer option provided" do
      expect(described_class.new(serializer_class, name: :name).relation?).to be false
      expect(described_class.new(serializer_class, name: :name, opts: {serializer: serializer_class}).relation?).to be true
    end
  end

  describe "#serializer" do
    subject(:serializer) { described_class.new(serializer_class, name: :name, opts: opts).serializer }

    let(:relation_serializer) { Class.new(Serega) }
    let(:opts) { {serializer: proc { relation_serializer }} }

    it "returns the resolved serializer class" do
      expect(serializer).to be relation_serializer
    end

    context "without a relation" do
      let(:opts) { {} }

      it "returns nil" do
        expect(serializer).to be_nil
      end
    end
  end

  describe "#value" do
    context "with no args" do
      it "gets value" do
        value = lambda { "NAME" }
        attribute = described_class.new(serializer_class, name: :name, opts: {value: value})
        expect(attribute.value(nil, nil)).to eq "NAME"
      end
    end

    context "with the :batch option" do
      it "returns the value from the loaded batch" do
        obj = double(id: 1)
        attribute = described_class.new(serializer_class, name: :name, opts: {batch: proc { |users| users }})
        expect(attribute.value(obj, nil, batches: {name: {1 => "NAME"}})).to eq "NAME"
      end
    end

    context "with the :const option" do
      it "returns the constant" do
        attribute = described_class.new(serializer_class, name: :name, opts: {const: "NAME"})
        expect(attribute.value(nil, nil)).to eq "NAME"
      end
    end

    context "with 1 arg" do
      it "gets value" do
        obj = double(name: "NAME")
        value = proc { |obj| obj.name }
        attribute = described_class.new(serializer_class, name: :name, opts: {value: value})
        expect(attribute.value(obj, nil)).to eq "NAME"
      end
    end

    context "with 2 args" do
      it "gets value" do
        obj = double(name: "NAME")
        ctx = {foo: "CTX"}
        value = lambda { |obj, ctx| [obj.name, ctx[:foo]] }
        attribute = described_class.new(serializer_class, name: :name, opts: {value: value})
        expect(attribute.value(obj, ctx)).to eq ["NAME", "CTX"]
      end
    end

    context "with 1 arg and ctx keyword" do
      it "gets value" do
        obj = double(name: "NAME")
        ctx = {foo: "CTX"}
        value = lambda { |obj, ctx:| [obj.name, ctx[:foo]] }
        attribute = described_class.new(serializer_class, name: :name, opts: {value: value})
        expect(attribute.value(obj, ctx)).to eq ["NAME", "CTX"]
      end
    end

    context "with 1 arg and batches keyword" do
      it "gets value" do
        obj = double(name: "NAME")
        ctx = nil
        batches = {foo: "LAZY"}
        value = lambda { |obj, batches:| [obj.name, batches[:foo]] }
        attribute = described_class.new(serializer_class, name: :name, opts: {value: value})
        expect(attribute.value(obj, ctx, batches: batches)).to eq ["NAME", "LAZY"]
      end
    end

    context "with 1 arg, ctx and batches keywords" do
      it "gets value" do
        obj = double(name: "NAME")
        ctx = {foo: "CTX"}
        batches = {foo: "LAZY"}
        value = lambda { |obj, ctx:, batches:| [obj.name, ctx[:foo], batches[:foo]] }
        attribute = described_class.new(serializer_class, name: :name, opts: {value: value})
        expect(attribute.value(obj, ctx, batches: batches)).to eq ["NAME", "CTX", "LAZY"]
      end
    end

    context "with 2 args, ctx and batches keywords" do
      it "gets value" do
        obj = double(name: "NAME")
        ctx = {foo: "CTX"}
        batches = {foo: "LAZY"}
        value = lambda { |obj, _context, ctx:, batches:| [obj.name, ctx[:foo], batches[:foo]] }
        attribute = described_class.new(serializer_class, name: :name, opts: {value: value})
        expect(attribute.value(obj, ctx, batches: batches)).to eq ["NAME", "CTX", "LAZY"]
      end
    end

    context "when returning value is nil" do
      it "returns default" do
        obj = nil
        ctx = {foo: "CTX"}
        value = lambda { |obj| obj }
        attribute = described_class.new(serializer_class, name: :name, opts: {value: value, default: 42})
        expect(attribute.value(obj, ctx)).to eq 42
      end
    end

    context "with the :format option" do
      it "returns the formatted value" do
        obj = double(balance: 1234)
        format = lambda { |cents, ctx| "#{cents / 100.0} #{ctx[:currency]}" }
        attribute = described_class.new(serializer_class, name: :balance, opts: {format: format})
        expect(attribute.value(obj, {currency: "EUR"})).to eq "12.34 EUR"
      end
    end

    it "works when attribute has name with `-` sign" do
      obj = double("-foo": "-bar")
      attribute = described_class.new(serializer_class, name: :"-foo")
      expect(attribute.value(obj, nil)).to eq "-bar"
    end
  end

  describe "#object_method" do
    subject(:object_method) { described_class.new(serializer_class, name: :full_name, opts: opts).object_method }

    let(:opts) { {} }

    it "returns the attribute name" do
      expect(object_method).to eq :full_name
    end

    context "with the :method option" do
      let(:opts) { {method: :name} }

      it "returns the method name" do
        expect(object_method).to eq :name
      end
    end

    context "with the :value option" do
      let(:opts) { {value: ->(user) { user.name }} }

      it "returns nil" do
        expect(object_method).to be_nil
      end
    end
  end

  describe "#source_methods" do
    subject(:source_methods) { described_class.new(serializer_class, name: :full_name, opts: opts).source_methods }

    let(:opts) { {} }

    it "returns the method that reads the value" do
      expect(source_methods).to eq [:full_name]
    end

    context "with the :value option" do
      let(:opts) { {value: ->(user) { user.name }} }

      it "returns nil" do
        expect(source_methods).to be_nil
      end
    end

    context "with a Symbol :if condition" do
      let(:opts) { {if: :active?} }

      it "returns the methods of the value and of the condition" do
        expect(source_methods).to eq %i[full_name active?]
      end
    end

    context "with a callable :if condition" do
      let(:opts) { {if: ->(user) { user.active? }} }

      it "returns nil" do
        expect(source_methods).to be_nil
      end
    end
  end

  describe "#reads_presenter?" do
    subject(:reads_presenter) { attribute.reads_presenter? }

    let(:attribute) { described_class.new(serializer_class, name: name) }
    let(:name) { :full_name }

    let(:presenter_class) do
      Class.new(Serega::SeregaPresenter) do
        def full_name = "#{first_name} #{last_name}"
      end
    end

    it "returns false" do
      expect(reads_presenter).to be false
    end

    context "when the attribute calls a presenter method" do
      before { attribute.check_presenter(presenter_class) }

      it "returns true" do
        expect(reads_presenter).to be true
      end
    end

    context "when the attribute calls no presenter method" do
      let(:name) { :first_name }

      before { attribute.check_presenter(presenter_class) }

      it "returns false" do
        expect(reads_presenter).to be false
      end
    end
  end

  describe "#value_callable" do
    subject(:value_callable) { described_class.new(serializer_class, name: :name, opts: opts).value_callable }

    let(:opts) { {value: value} }
    let(:value) { proc { |user| user.name } }

    it "returns the :value callable" do
      expect(value_callable).to equal value
    end

    context "without the :value option" do
      let(:opts) { {} }

      it "returns nil" do
        expect(value_callable).to be_nil
      end
    end
  end
end
