# frozen_string_literal: true

RSpec.describe Serega::AttributeNormalizers::BlockSerializer do
  subject(:nested) { described_class.call(serializer_class, :author, block, base_option) }

  let(:base_serializer) { Class.new(Serega) }
  let(:block) { proc { attribute :name } }
  let(:base_option) { nil }

  let(:serializer_class) do
    base = base_serializer
    Class.new(Serega) do
      config.base_serializer = base
      attribute :id
    end
  end

  it "builds a subclass of config.base_serializer with the block attributes only" do
    expect(nested).to be < base_serializer
    expect(nested).not_to be < serializer_class
    expect(nested.attributes.keys).to eq [:name]
  end

  it "labels the nested serializer with the serializer and attribute names" do
    expect(nested.inspect).to eq "#{serializer_class.inspect}.<author>"
    expect(nested.to_s).to eq "#{serializer_class.inspect}.<author>"
  end

  context "with the :base_serializer option" do
    let(:base_option) { Class.new(Serega) }

    it "builds a subclass of the option" do
      expect(nested).to be < base_option
    end
  end

  context "without a base serializer" do
    let(:serializer_class) { Class.new(Serega) }

    it "raises an error" do
      expect { nested }.to raise_error Serega::SeregaError,
        "Attribute block requires a base serializer for the nested serializer." \
        " Provide the `base_serializer: <SerializerClass>` attribute option" \
        " or set `config.base_serializer = <SerializerClass>`"
    end
  end

  context "with a block that defines no attributes" do
    let(:block) { proc {} }

    it "raises an explaining error" do
      expect { nested }
        .to raise_error Serega::SeregaError, Serega::SeregaValidations::Attribute::CheckBlock::ERROR_MESSAGE
    end
  end

  context "when the base serializer has attributes, batch loaders, a preload handler and plugins" do
    let(:handler) { proc { |objects, preloads| [objects, preloads] } }

    let(:base_serializer) do
      preload_handler = handler
      Class.new(Serega) do
        plugin :root
        attribute :id
        batch(:stats, proc { |objects| {} })
        preload_with(preload_handler)
      end
    end

    it "inherits them" do
      expect(nested.attributes.keys).to eq %i[id name]
      expect(nested.batch_loaders.keys).to eq [:stats]
      expect(nested.preload_with).to equal handler
      expect(nested.plugin_used?(:root)).to be true
    end
  end

  context "when the base serializer has a block attribute with another block" do
    let(:base_serializer) do
      Class.new(Serega) do
        config.base_serializer = Class.new(Serega)
        attribute(:meta, method: :itself) { attribute :version }
      end
    end

    it "builds the nested serializer" do
      expect(nested.attributes.keys).to eq %i[meta name]
    end
  end

  context "when the base serializer has a block attribute with the same block" do
    let(:base_option) do
      same_block = block
      Class.new(Serega) do
        config.base_serializer = self
        attribute(:meta, method: :itself, &same_block)
      end
    end

    it "raises an error" do
      expect { nested }.to raise_error Serega::SeregaError,
        "Can not define a nested serializer for attribute :meta —" \
        " its base serializer #{base_option.inspect} (transitively)" \
        " contains this same block attribute (cyclic definition)"
    end
  end
end
