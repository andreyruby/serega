# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::CheckAttributeParams do
  subject(:validate) { described_class.new(*params).validate }

  let(:serializer) { Class.new(Serega) }
  let(:name) { :name }
  let(:opts) { {opt1: :foo, opt2: :bar} }
  let(:block) { proc {} }
  let(:params) { [name, opts, block] }
  let(:described_class) { serializer::CheckAttributeParams }

  before do
    allow(Serega::SeregaValidations::Utils::CheckAllowedKeys).to receive(:call)
    allow(Serega::SeregaValidations::Attribute::CheckBlock).to receive(:call)
    allow(Serega::SeregaValidations::Attribute::CheckName).to receive(:call)
    allow(Serega::SeregaValidations::Attribute::CheckOptConst).to receive(:call)
    allow(Serega::SeregaValidations::Attribute::CheckOptHide).to receive(:call)
    allow(Serega::SeregaValidations::Attribute::CheckOptBatch).to receive(:call)
    allow(Serega::SeregaValidations::Attribute::CheckOptMethod).to receive(:call)
    allow(Serega::SeregaValidations::Attribute::CheckOptMany).to receive(:call)
    allow(Serega::SeregaValidations::Attribute::CheckOptSerializer).to receive(:call)
    allow(Serega::SeregaValidations::Attribute::CheckOptValue).to receive(:call)
  end

  it "checks valid keys" do
    validate

    expect(Serega::SeregaValidations::Utils::CheckAllowedKeys)
      .to have_received(:call).with(opts, serializer.config.attribute_keys, :attribute)
  end

  it "checks each option value" do
    validate

    expect(Serega::SeregaValidations::Attribute::CheckBlock).to have_received(:call).with(block)
    expect(Serega::SeregaValidations::Attribute::CheckName).to have_received(:call).with(name)
    expect(Serega::SeregaValidations::Attribute::CheckOptConst).to have_received(:call).with(opts, block)
    expect(Serega::SeregaValidations::Attribute::CheckOptHide).to have_received(:call).with(opts)
    expect(Serega::SeregaValidations::Attribute::CheckOptBatch).to have_received(:call).with(serializer, opts, block)
    expect(Serega::SeregaValidations::Attribute::CheckOptMethod).to have_received(:call).with(opts, block)
    expect(Serega::SeregaValidations::Attribute::CheckOptMany).to have_received(:call).with(opts)
    expect(Serega::SeregaValidations::Attribute::CheckOptSerializer).to have_received(:call).with(opts)
    expect(Serega::SeregaValidations::Attribute::CheckOptValue).to have_received(:call).with(opts, block)
  end

  it "skips checking name if names check is disabled" do
    serializer.config.check_attribute_name = false
    validate

    expect(Serega::SeregaValidations::Attribute::CheckName).not_to have_received(:call)
  end
end
