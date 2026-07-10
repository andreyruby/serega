# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptMany do
  def error(value)
    "Invalid option :many => #{value.inspect}. Must have a boolean value"
  end

  it "allows to provide :many option only with :serializer, :batch option or a block" do
    block = proc { attribute :text }
    expect { described_class.call(serializer: "foo", many: true) }.not_to raise_error
    expect { described_class.call(serializer: "foo", many: false) }.not_to raise_error
    expect { described_class.call(batch: {}, many: true) }.not_to raise_error
    expect { described_class.call(batch: {}, many: false) }.not_to raise_error
    expect { described_class.call({many: true}, block) }.not_to raise_error
    expect { described_class.call({many: false}, block) }.not_to raise_error

    expect { described_class.call(many: true) }
      .to raise_error Serega::SeregaError, "Option :many can be provided only together with :serializer, :batch option or a block"
    expect { described_class.call(many: false) }
      .to raise_error Serega::SeregaError, "Option :many can be provided only together with :serializer, :batch option or a block"
  end

  it "allows only boolean values" do
    expect { described_class.call(serializer: "foo", many: true) }.not_to raise_error
    expect { described_class.call(serializer: "foo", many: false) }.not_to raise_error
    expect { described_class.call(serializer: "foo", many: nil) }.to raise_error Serega::SeregaError, error(nil)
    expect { described_class.call(serializer: "foo", many: 0) }.to raise_error Serega::SeregaError, error(0)
  end
end
