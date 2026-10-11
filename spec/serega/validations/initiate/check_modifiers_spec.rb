# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Initiate::CheckModifiers do
  let(:base_serializer) do
    serializer_class = Class.new(Serega)
    serializer_class.plugin :string_modifiers
    serializer_class
  end

  let(:serializer) do
    serializer_class = Class.new(base_serializer)
    serializer_class.attribute :foo_bar
    serializer_class.attribute :foo_bazz, serializer: serializer_class
    serializer_class
  end

  it "does not raise error when all provided fields present" do
    attrs = "foo_bar,foo_bazz(foo_bar)"
    expect { serializer.new(only: attrs, with: attrs, except: attrs) }.not_to raise_error
  end

  it "raises error when some provided field not exist" do
    attrs = "foo_bar,extra"
    message = "Not existing attributes: extra"
    expect { serializer.new(only: attrs) }.to raise_error Serega::AttributeNotExist, message
    expect { serializer.new(with: attrs) }.to raise_error Serega::AttributeNotExist, message
    expect { serializer.new(except: attrs) }.to raise_error Serega::AttributeNotExist, message
  end

  it "raises when multiple provided field not exist" do
    attrs = "foo,foo_bar,extra"
    message = "Not existing attributes: foo, extra"
    expect { serializer.new(only: attrs) }.to raise_error Serega::AttributeNotExist, message
    expect { serializer.new(with: attrs) }.to raise_error Serega::AttributeNotExist, message
    expect { serializer.new(except: attrs) }.to raise_error Serega::AttributeNotExist, message
  end

  it "raises when multiple provided fields not exist from multiple params" do
    expect { serializer.new(only: "only", with: "with", except: "except") }
      .to raise_error Serega::AttributeNotExist, "Not existing attributes: only, with, except"
  end

  it "raises when provided not existing attribute in nested serializer" do
    attrs = "foo_bazz(extra)"
    message = "Not existing attributes: foo_bazz(extra)"

    expect { serializer.new(only: attrs) }.to raise_error do |error|
      expect(error).to be_a Serega::AttributeNotExist
      expect(error.message).to eq message
      expect(error.serializer).to eq serializer
      expect(error.attributes).to eq ["foo_bazz(extra)"]
    end

    expect { serializer.new(with: attrs) }.to raise_error Serega::AttributeNotExist, message
    expect { serializer.new(except: attrs) }.to raise_error Serega::AttributeNotExist, message
  end

  it "raises when provided nested attribute for not nested parent attribute" do
    attrs = "foo_bar(extra)"
    message = "Not existing attributes: foo_bar(extra)"

    expect { serializer.new(only: attrs) }.to raise_error do |error|
      expect(error).to be_a Serega::AttributeNotExist
      expect(error.message).to eq message
      expect(error.serializer).to eq serializer
      expect(error.attributes).to eq ["foo_bar(extra)"]
    end

    expect { serializer.new(with: attrs) }.to raise_error Serega::AttributeNotExist, message
    expect { serializer.new(except: attrs) }.to raise_error Serega::AttributeNotExist, message
  end
end
