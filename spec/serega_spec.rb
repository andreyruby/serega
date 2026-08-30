# frozen_string_literal: true

RSpec.describe Serega do
  let(:serializer_class) { Class.new(described_class) }

  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  describe ".inherited" do
    it "inherits config" do
      parent_ser = Class.new(described_class)
      child_ser = Class.new(parent_ser)
      parent = parent_ser.config
      child = child_ser.config

      # Check config values are inherited
      expect(child.__send__(:opts)).to eq parent.__send__(:opts)
      expect(child.__send__(:opts)).not_to equal parent.__send__(:opts)

      # Check child config does not overwrite parent config values
      child.attribute_keys << :foo
      expect(parent.attribute_keys).not_to include :foo

      # Check child config does not adds new keys to parent config
      child.__send__(:opts)[:foo] = 123
      expect(parent.__send__(:opts)).not_to have_key(:foo)

      # Check child config is a subclass of parent config
      expect(child.class.superclass).to eq parent.class
    end

    it "inherits attributes" do
      parent = Class.new(described_class)
      parent.attribute(:foo)

      # Check attributes are copied to child attributes
      child = Class.new(parent)
      expect(child.attributes[:foo].class.superclass).to eq parent.attributes[:foo].class
    end

    it "inherits same batch loaders" do
      parent = Class.new(described_class)
      parent.batch(:foo, proc { |objects| objects })

      child = Class.new(parent)
      expect(child.batch_loaders).to have_key(:foo)
      expect(child.batch_loaders[:foo].load(1, nil)).to eq 1
    end

    it "inherits the preload_with handler" do
      handler = proc { |objects, preloads| [objects, preloads] }
      parent = Class.new(described_class)
      parent.preload_with(handler)

      child = Class.new(parent)
      expect(child.preload_with).to equal handler
    end

    it "allows child to override preload_with without affecting parent" do
      parent_handler = proc { |objects, preloads| :parent }
      child_handler = proc { |objects, preloads| :child }
      parent = Class.new(described_class)
      parent.preload_with(parent_handler)

      child = Class.new(parent)
      child.preload_with(child_handler)

      expect(child.preload_with).to equal child_handler
      expect(parent.preload_with).to equal parent_handler
    end

    it "inherits the prepare_initial_objects handler" do
      handler = proc { |objects| objects }
      parent = Class.new(described_class)
      parent.prepare_initial_objects(handler)

      child = Class.new(parent)
      expect(child.prepare_initial_objects).to equal handler
    end

    it "allows child to override prepare_initial_objects without affecting parent" do
      parent_handler = proc { |objects| :parent }
      child_handler = proc { |objects| :child }
      parent = Class.new(described_class)
      parent.prepare_initial_objects(parent_handler)

      child = Class.new(parent)
      child.prepare_initial_objects(child_handler)

      expect(child.prepare_initial_objects).to equal child_handler
      expect(parent.prepare_initial_objects).to equal parent_handler
    end

    it "inherits serialization class" do
      parent = Class.new(described_class)
      child = Class.new(parent)

      expect(child::SeregaObjectSerializer.superclass).to eq parent::SeregaObjectSerializer
    end
  end

  describe ".attribute" do
    it "adds new attribute" do
      attribute = serializer_class.attribute "foo"
      expect(serializer_class.attributes).to eq(foo: attribute)
    end
  end

  describe ".attributes" do
    it "returns empty hash when no attributes added" do
      expect(serializer_class.attributes).to eq({})
    end

    it "returns list of added attributes" do
      foo = serializer_class.attribute :foo
      bar = serializer_class.attribute :bar

      expect(serializer_class.attributes).to eq(foo: foo, bar: bar)
    end
  end
end
