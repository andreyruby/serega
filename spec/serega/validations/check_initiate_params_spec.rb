# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::CheckInitiateParams do
  subject(:validate) { described_class.new(opts).validate }

  let(:serializer) { Class.new(Serega) }
  let(:opts) { {only: {foo: {}}, except: {bar: {}}, with: {bazz: {}}} }
  let(:described_class) { serializer::CheckInitiateParams }
  let(:check_modifiers) { Serega::SeregaValidations::Initiate::CheckModifiers.new }

  before do
    allow(Serega::SeregaValidations::Utils::CheckAllowedKeys).to receive(:call)
    allow(Serega::SeregaValidations::Initiate::CheckModifiers).to receive(:new).and_return(check_modifiers)
    allow(check_modifiers).to receive(:call)
  end

  it "checks valid keys and modifiers fields" do
    validate

    expect(Serega::SeregaValidations::Utils::CheckAllowedKeys)
      .to have_received(:call).with(opts, serializer.config.initiate_keys, :initiate)

    expect(check_modifiers)
      .to have_received(:call)
      .with(serializer, {foo: {}}, {bazz: {}}, {bar: {}})
  end

  describe "validating initiate params" do
    let(:serializer_class) { Class.new(Serega) }

    let(:validator) { instance_double(serializer_class::CheckInitiateParams, validate: nil) }
    let(:modifiers) { {only: "foo"} }

    before do
      allow(serializer_class::CheckInitiateParams).to receive(:new).and_return(validator)
    end

    it "validates initiate params by default" do
      serializer_class.to_h(nil, modifiers)

      expect(serializer_class::CheckInitiateParams).to have_received(:new).with(only: {foo: {}})
      expect(validator).to have_received(:validate)
    end

    it "allows to disable validation via config option" do
      serializer_class.config.check_initiate_params = false
      serializer_class.to_h(nil, modifiers)

      expect(serializer_class::CheckInitiateParams).not_to have_received(:new)
    end

    it "allows to disable validation via check_initiate_params param" do
      serializer_class.to_h(nil, **modifiers, check_initiate_params: false)

      expect(serializer_class::CheckInitiateParams).not_to have_received(:new)
    end
  end
end
