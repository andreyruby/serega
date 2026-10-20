# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::CheckSerializeParams do
  subject(:validate) { described_class.new(opts).validate }

  let(:serializer) { Class.new(Serega) }
  let(:described_class) { serializer::CheckSerializeParams }
  let(:opts) { {root: :user} }

  before { allow(Serega::SeregaValidations::Utils::CheckAllowedKeys).to receive(:call) }

  it "checks the option names" do
    validate

    expect(Serega::SeregaValidations::Utils::CheckAllowedKeys)
      .to have_received(:call).with(opts, serializer.config.serialize_keys, :serialize)
  end
end
