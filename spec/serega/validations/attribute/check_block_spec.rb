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

  it "hints the :value option in the error message" do
    expect(described_class::ERROR_MESSAGE).to eq <<~MESSAGE.chomp
      Attribute block defines a nested serializer and must define its attributes
      (hint: to compute the attribute value, use the `value: <callable>` option)
    MESSAGE
  end
end
