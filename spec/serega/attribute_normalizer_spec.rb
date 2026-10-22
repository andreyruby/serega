# frozen_string_literal: true

RSpec.describe Serega::SeregaAttributeNormalizer do
  let(:serializer_class) { Class.new(Serega) }

  describe "#name" do
    it "symbolizes name" do
      attribute = described_class.new(serializer_class, name: "current_name")
      expect(attribute.name).to eq :current_name
    end
  end

  describe "#method_name" do
    it "returns symbolized :method options" do
      attribute = described_class.new(serializer_class, name: "current_name", opts: {method: "method"})
      expect(attribute.method_name).to eq :method
    end

    it "returns name when :method option not provided" do
      attribute = described_class.new(serializer_class, name: "current_name", opts: {})
      expect(attribute.method_name).to eq :current_name
    end
  end

  describe "#formatter" do
    subject(:formatter) { described_class.new(serializer_class, name: :balance, opts: opts).formatter }

    let(:money) { ->(cents) { cents / 100.0 } }

    before { serializer_class.formatter(:money, money) }

    context "without the :format option" do
      let(:opts) { {} }

      it "returns nil" do
        expect(formatter).to be_nil
      end
    end

    context "with a formatter name" do
      let(:opts) { {format: :money} }

      it "returns the added formatter" do
        expect(formatter.call(1234, nil)).to eq 12.34
      end
    end

    context "with a callable" do
      let(:opts) { {format: ->(score) { "#{score}%" }} }

      it "returns the callable formatter" do
        expect(formatter.call(50, nil)).to eq "50%"
      end
    end
  end

  describe "#many" do
    it "returns provided :many option" do
      expect(described_class.new(serializer_class, opts: {many: true}).many).to be true
      expect(described_class.new(serializer_class, opts: {many: false}).many).to be false
      expect(described_class.new(serializer_class, opts: {}).many).to be_nil
    end

    it "returns saved :many option" do
      norm = described_class.new(serializer_class, opts: {many: true})
      expect(norm.many).to be true
      expect(norm.instance_variable_get(:@many)).to be true

      norm.instance_variable_set(:@many, nil)
      expect(norm.many).to be_nil
    end
  end

  describe "#default" do
    it "returns provided :default option" do
      expect(described_class.new(serializer_class, opts: {default: 123, many: true}).default).to eq 123
    end

    it "returns saved :default option" do
      default = []
      norm = described_class.new(serializer_class, opts: {default: default})
      expect(norm.default).to equal default
      expect(norm.default).to equal norm.default
    end

    it "returns empty array if no default provided, but many: true provided" do
      norm = described_class.new(serializer_class, opts: {many: true})
      expect(norm.default).to equal Serega::FROZEN_EMPTY_ARRAY
    end
  end

  describe "#hide" do
    it "returns provided :hide option" do
      expect(described_class.new(serializer_class, opts: {hide: true}).hide).to be true
      expect(described_class.new(serializer_class, opts: {hide: false}).hide).to be false
      expect(described_class.new(serializer_class, opts: {}).hide).to be_nil
    end

    it "returns saved :hide option" do
      norm = described_class.new(serializer_class, opts: {hide: true})

      expect(norm.hide).to be true
      expect(norm.instance_variable_get(:@hide)).to be true

      norm.instance_variable_set(:@hide, nil)
      expect(norm.hide).to be_nil
    end

    context "with hide_by_default: :auto" do
      before { serializer_class.config.hide_by_default = :auto }

      it "hides attribute with :preload" do
        expect(described_class.new(serializer_class, name: :foo, opts: {preload: :foo}).hide).to be true
      end

      it "hides attribute with :batch" do
        expect(described_class.new(serializer_class, name: :foo, opts: {batch: true}).hide).to be true
      end

      it "does not hide plain attribute" do
        expect(described_class.new(serializer_class, name: :foo, opts: {}).hide).to be_nil
      end

      it "does not hide attribute with :preload when preloads resolve to nil" do
        expect(described_class.new(serializer_class, name: :foo, opts: {preload: false}).hide).to be_nil
      end

      it "hides attribute with empty :batch use list (batch key present)" do
        expect(described_class.new(serializer_class, name: :foo, opts: {batch: {use: []}}).hide).to be(true)
      end

      it "does not hide attribute when auto preload resolves to an excluded method" do
        serializer_class.config.auto_preload = true
        norm = described_class.new(serializer_class, name: :statistics, opts: {serializer: "bar", method: :itself})
        expect(norm.hide).to be_nil
      end
    end

    context "with hide_by_default: true" do
      it "returns true for any attribute without explicit hide option" do
        serializer_class.config.hide_by_default = true
        expect(described_class.new(serializer_class, opts: {}).hide).to be true
      end

      it "returns true for explicit hide: true" do
        serializer_class.config.hide_by_default = true
        expect(described_class.new(serializer_class, opts: {hide: true}).hide).to be true
      end

      it "returns false for explicit hide: false — attribute-level wins over config" do
        serializer_class.config.hide_by_default = true
        expect(described_class.new(serializer_class, opts: {hide: false}).hide).to be false
      end
    end
  end

  describe "#serializer" do
    it "returns provided :serializer option" do
      expect(described_class.new(serializer_class, opts: {serializer: 123}).serializer).to eq 123
    end

    it "returns saved :serializer option" do
      norm = described_class.new(serializer_class, opts: {serializer: true})

      expect(norm.serializer).to be true
      expect(norm.instance_variable_get(:@serializer)).to be true

      norm.instance_variable_set(:@serializer, nil)
      expect(norm.serializer).to be_nil
    end

    context "with a block" do
      let(:block) { proc { attribute :name } }
      let(:base_serializer) { Class.new(Serega) }
      let(:nested) { Class.new(Serega) }

      before do
        allow(Serega::AttributeNormalizers::BlockSerializer).to receive(:call).and_return(nested)
      end

      it "builds the nested serializer from the block" do
        normalizer = described_class.new(serializer_class, name: :author, opts: {base_serializer: base_serializer}, block: block)

        expect(normalizer.serializer).to be nested

        expect(Serega::AttributeNormalizers::BlockSerializer)
          .to have_received(:call).with(serializer_class, :author, block, base_serializer)
      end
    end
  end

  describe "#prepare_value_block" do
    it "ignores provided block, it defines a nested serializer, not a value" do
      block = proc {}
      resolver = described_class.new(serializer_class, name: :length, opts: {}, block: block).send(:prepare_value_block)
      expect(resolver).to be_a(Serega::AttributeValueResolvers::Keyword)
    end

    it "returns provided value option" do
      value = lambda { |one, two| }
      attribute = described_class.new(serializer_class, opts: {value: value})
      expect(attribute.send(:prepare_value_block)).to equal value
    end

    it "returns resolver generated by :method option" do
      resolver = described_class.new(serializer_class, opts: {method: :length}).send(:prepare_value_block)
      expect(resolver).to be_a(Serega::AttributeValueResolvers::Keyword)
      expect(resolver.call(double(length: 3))).to eq 3
    end

    it "returns resolver generated by :batch option" do
      batches_values = {attr1: {foo: 1}}

      resolver = described_class.new(
        serializer_class,
        name: :attr1,
        opts: {
          batch: {id: :itself}
        }
      ).send(:prepare_value_block)
      expect(resolver).to be_a(Serega::AttributeValueResolvers::Batch)
      expect(resolver.call(:foo, batches: batches_values)).to eq 1
    end

    it "returns resolver generated by :const option" do
      const = "123"
      resolver = described_class.new(serializer_class, opts: {const: const}).send(:prepare_value_block)
      expect(resolver).to be_a(Serega::AttributeValueResolvers::Const)
      expect(resolver.call).to be const
    end

    context "with the :delegate option" do
      let(:delegate) { {to: :profile} }
      let(:resolver) { proc {} }

      before do
        allow(Serega::AttributeNormalizers::Delegate).to receive(:call).and_return(resolver)
      end

      it "returns the resolver built from the option" do
        normalizer = described_class.new(serializer_class, name: :name, opts: {delegate: delegate})

        expect(normalizer.send(:prepare_value_block)).to be resolver

        expect(Serega::AttributeNormalizers::Delegate)
          .to have_received(:call).with(delegate, :name, serializer_class.config)
      end
    end
  end

  describe "prepare_batch_loaders" do
    def batch_loaders(name:, opts:)
      described_class.new(serializer_class, name: name, opts: opts).send(:prepare_batch_loaders)
    end

    it "returns array of required batch loader names to send to attribute" do
      # Only explicit :batch attributes need a loader; everything else resolves
      # its value from the record, so the list is empty.
      expect(batch_loaders(name: :foo, opts: {})).to eq %i[]
      expect(batch_loaders(name: :foo, opts: {batch: true})).to eq %i[foo]
      expect(batch_loaders(name: :foo, opts: {batch: proc {}})).to eq %i[foo]
      expect(batch_loaders(name: :foo, opts: {batch: :bar})).to eq %i[bar]
      expect(batch_loaders(name: :foo, opts: {batch: "bar"})).to eq %i[bar]
      expect(batch_loaders(name: :foo, opts: {batch: {use: proc {}}})).to eq %i[foo]
      expect(batch_loaders(name: :foo, opts: {batch: {use: :bar}})).to eq %i[bar]
      expect(batch_loaders(name: :foo, opts: {batch: {use: "bar"}})).to eq %i[bar]
      expect(batch_loaders(name: :foo, opts: {batch: {use: %i[bar bazz]}})).to eq %i[bar bazz]
      expect(batch_loaders(name: :foo, opts: {batch: {use: %w[bar bazz]}})).to eq %i[bar bazz]
    end
  end

  describe "#inline_batch_loader" do
    subject(:loader) { described_class.new(serializer_class, name: :likes_count, opts: opts).inline_batch_loader }

    let(:likes) { ->(users) { users.to_h { |user| [user.id, 10] } } }

    context "with a callable :batch option" do
      let(:opts) { {batch: likes} }

      it "returns a batch loader named after the attribute" do
        expect(loader).to be_a(Serega::SeregaBatchLoader).and have_attributes(name: :likes_count, block: likes)
      end
    end

    context "with a callable :use" do
      let(:opts) { {batch: {use: likes}} }

      it "returns a batch loader named after the attribute" do
        expect(loader).to have_attributes(name: :likes_count, block: likes)
      end
    end

    context "with a named batch loader" do
      let(:opts) { {batch: :likes} }

      it "returns nil" do
        expect(loader).to be_nil
      end
    end

    context "without the :batch option" do
      let(:opts) { {} }

      it "returns nil" do
        expect(loader).to be_nil
      end
    end
  end

  describe "#value_block with the :batch option" do
    subject(:resolver) { described_class.new(serializer_class, name: :likes_count, opts: {batch: batch}).value_block }

    before { serializer_class.config.batch_id_option = :uuid }

    context "with true" do
      let(:batch) { true }

      it "reads the batch of the loader named after the attribute by the default id" do
        expect(resolver).to have_attributes(class: Serega::AttributeValueResolvers::Batch)
        expect(resolver.instance_variable_get(:@loader_name)).to eq :likes_count
        expect(resolver.instance_variable_get(:@id_method)).to eq :uuid
      end
    end

    context "with a loader name and an id" do
      let(:batch) { {use: "likes", id: :user_id} }

      it "reads the batch of the loader by the id" do
        expect(resolver.instance_variable_get(:@loader_name)).to eq :likes
        expect(resolver.instance_variable_get(:@id_method)).to eq :user_id
      end
    end

    context "with an id only" do
      let(:batch) { {id: :user_id} }

      it "reads the batch of the loader named after the attribute by the id" do
        expect(resolver.instance_variable_get(:@loader_name)).to eq :likes_count
        expect(resolver.instance_variable_get(:@id_method)).to eq :user_id
      end
    end
  end

  describe "batch-all-attributes experiment" do
    it "registers no synthetic loaders — only explicit :batch attributes have any" do
      child = Class.new(Serega)
      serializer = Class.new(Serega) do
        attribute :title
        attribute :author, serializer: child
        attribute :likes, preload: :likes, value: proc { |o| o }
      end

      # relations, preloads and plain attributes carry no batch loader;
      # their value comes from the record, they are just routed through the
      # batch phase unconditionally by the object serializer.
      expect(serializer.batch_loaders).to be_empty
      expect(serializer.attributes[:title].batch_loaders).to be_empty
      expect(serializer.attributes[:author].batch_loaders).to be_empty
      expect(serializer.attributes[:likes].batch_loaders).to be_empty
    end

    describe "hide_by_default :auto" do
      it "keeps a plain serializer relation visible" do
        child = Class.new(Serega)
        serializer = Class.new(Serega) do
          config.hide_by_default = :auto
          attribute :author, serializer: child
        end
        expect(serializer.attributes[:author].hide).to be_nil
      end

      it "hides attributes declared with :preload or :batch" do
        serializer = Class.new(Serega) do
          config.hide_by_default = :auto
          attribute :a, preload: :a, value: proc { |o| o }
          attribute :b, batch: proc { |objs| objs.to_h { |o| [o, o] } }
        end
        expect(serializer.attributes[:a].hide).to be(true)
        expect(serializer.attributes[:b].hide).to be(true)
      end
    end
  end

  describe "#preloads" do
    let(:block) { proc { attribute :title } }
    let(:opts) { {method: :articles} }

    before do
      allow(Serega::AttributeNormalizers::Preloads).to receive(:call).and_return(:articles)
    end

    it "finds the preloads from the attribute options" do
      normalizer = described_class.new(serializer_class, name: :posts, opts: opts, block: block)

      expect(normalizer.preloads).to eq :articles

      expect(Serega::AttributeNormalizers::Preloads)
        .to have_received(:call).with(opts, block, :articles, serializer_class.config)
    end
  end
end
