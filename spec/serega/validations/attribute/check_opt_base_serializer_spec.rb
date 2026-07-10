# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptBaseSerializer do
  let(:block) { proc { attribute :name } }

  it "allows no :base_serializer option" do
    expect { described_class.call({foo: nil}, block) }.not_to raise_error
    expect { described_class.call({foo: nil}) }.not_to raise_error
  end

  it "allows Serega and Serega subclasses" do
    expect { described_class.call({base_serializer: Serega}, block) }.not_to raise_error
    expect { described_class.call({base_serializer: Class.new(Serega)}, block) }.not_to raise_error
  end

  it "prohibits to use without a block" do
    expect { described_class.call({base_serializer: Serega}) }
      .to raise_error Serega::SeregaError, "Option :base_serializer can be used only with a block"
  end

  it "prohibits values that are not Serega subclasses" do
    expect { described_class.call({base_serializer: nil}, block) }
      .to raise_error Serega::SeregaError, "Invalid option :base_serializer => nil. Must be a Serega subclass"
    expect { described_class.call({base_serializer: Object}, block) }
      .to raise_error Serega::SeregaError, "Invalid option :base_serializer => Object. Must be a Serega subclass"
    expect { described_class.call({base_serializer: "UserSerializer"}, block) }
      .to raise_error Serega::SeregaError, "Invalid option :base_serializer => \"UserSerializer\". Must be a Serega subclass"
  end
end
