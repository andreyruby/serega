# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckBlock do
  it "allows no block" do
    expect { described_class.call(nil) }.not_to raise_error
  end

  it "allows a block with no parameters" do
    expect { described_class.call(proc {}) }.not_to raise_error
    expect { described_class.call(lambda {}) }.not_to raise_error
  end

  it "prohibits a block with positional parameters" do
    expect { described_class.call(lambda { |object| }) }
      .to raise_error Serega::SeregaError, described_class::ERROR_MESSAGE
    expect { described_class.call(proc { |object, context| }) }
      .to raise_error Serega::SeregaError, described_class::ERROR_MESSAGE
  end

  it "prohibits a block with keyword parameters" do
    expect { described_class.call(lambda { |ctx:| }) }
      .to raise_error Serega::SeregaError, described_class::ERROR_MESSAGE
  end

  it "explains the changed block behavior in the error message" do
    expect(described_class::ERROR_MESSAGE).to include "defines a nested serializer"
    expect(described_class::ERROR_MESSAGE).to include "use the `value: <callable>` option instead"
  end
end
