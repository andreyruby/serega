# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::CheckAttributeParams do
  subject(:validate) { described_class.new(*params).validate }

  let(:serializer) { Class.new(Serega) }
  let(:name) { :name }
  let(:opts) { {opt1: :foo, opt2: :bar} }
  let(:block) { proc {} }
  let(:params) { [serializer, name, opts, block] }

  before do
    allow(Serega::SeregaValidations::Utils::CheckAllowedKeys).to receive(:call)
    allow(Serega::SeregaValidations::Attribute::CheckBlock).to receive(:call)
    allow(Serega::SeregaValidations::Attribute::CheckName).to receive(:call)
    allow(Serega::SeregaValidations::Attribute::CheckOptBaseSerializer).to receive(:call)
    allow(Serega::SeregaValidations::Attribute::CheckOptCondition).to receive(:call)
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
    expect(Serega::SeregaValidations::Attribute::CheckOptBaseSerializer).to have_received(:call).with(opts, block)
    expect(Serega::SeregaValidations::Attribute::CheckOptCondition).to have_received(:call).with(opts, :if)
    expect(Serega::SeregaValidations::Attribute::CheckOptCondition).to have_received(:call).with(opts, :unless)
    expect(Serega::SeregaValidations::Attribute::CheckOptCondition).to have_received(:call).with(opts, :if_value)
    expect(Serega::SeregaValidations::Attribute::CheckOptCondition).to have_received(:call).with(opts, :unless_value)
    expect(Serega::SeregaValidations::Attribute::CheckOptConst).to have_received(:call).with(opts)
    expect(Serega::SeregaValidations::Attribute::CheckOptHide).to have_received(:call).with(opts)
    expect(Serega::SeregaValidations::Attribute::CheckOptBatch).to have_received(:call).with(serializer, name, opts)
    expect(Serega::SeregaValidations::Attribute::CheckOptMethod).to have_received(:call).with(opts)
    expect(Serega::SeregaValidations::Attribute::CheckOptMany).to have_received(:call).with(opts, block, false)
    expect(Serega::SeregaValidations::Attribute::CheckOptSerializer).to have_received(:call).with(opts, block)
    expect(Serega::SeregaValidations::Attribute::CheckOptValue).to have_received(:call).with(opts)
  end

  context "when the config requires the :many option" do
    let(:serializer) { Class.new(Serega) { config.require_many = true } }

    it "checks the :many option as required" do
      validate

      expect(Serega::SeregaValidations::Attribute::CheckOptMany).to have_received(:call).with(opts, block, true)
    end
  end

  it "skips checking name if names check is disabled" do
    serializer.config.check_attribute_name = false
    validate

    expect(Serega::SeregaValidations::Attribute::CheckName).not_to have_received(:call)
  end
end
