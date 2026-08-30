# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::CheckSerializeParams do
  subject(:validate) { described_class.new(opts).validate }

  let(:serializer) do
    Class.new(Serega)
  end
  let(:opts) { {only: :foo, except: :bar, with: :bazz} }
  let(:described_class) { serializer::CheckSerializeParams }

  before do
    allow(Serega::SeregaValidations::Utils::CheckAllowedKeys).to receive(:call)
    allow(Serega::SeregaValidations::Utils::CheckOptIsHash).to receive(:call)
    allow(Serega::SeregaValidations::Utils::CheckOptIsBool).to receive(:call)
  end

  it "checks valid keys" do
    validate
    expect(Serega::SeregaValidations::Utils::CheckAllowedKeys).to have_received(:call).with(opts, serializer.config.serialize_keys, :serialize)
    expect(Serega::SeregaValidations::Utils::CheckOptIsHash).to have_received(:call).with(opts, :context)
    expect(Serega::SeregaValidations::Utils::CheckOptIsBool).to have_received(:call).with(opts, :many)
  end

  describe "validating serialize params" do
    let(:serializer_class) { Class.new(Serega) }

    let(:validator) { instance_double(serializer_class::CheckSerializeParams, validate: nil) }
    let(:params) { {only: {}, except: {}, with: {}, context: {foo: "bar"}, a: 1} }

    before do
      allow(serializer_class::CheckSerializeParams).to receive(:new).and_return(validator)
    end

    it "selects serialize params (not modifiers params) and validates them" do
      serializer_class.to_h(nil, params)

      expect(serializer_class::CheckSerializeParams).to have_received(:new).with(hash_including(context: {foo: "bar"}, a: 1))
      expect(validator).to have_received(:validate)
    end
  end
end
