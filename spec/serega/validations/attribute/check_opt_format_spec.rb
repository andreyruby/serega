# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptFormat do
  subject(:check) { described_class.call(opts, serializer_class) }

  let(:serializer_class) { Class.new(Serega) }
  let(:opts) { {format: format} }
  let(:format) { :money }

  before do
    serializer_class.formatter(:money, ->(cents) { cents / 100.0 })
    allow(Serega::SeregaValidations::CheckFormatter).to receive(:call)
  end

  context "without the :format option" do
    let(:opts) { {} }

    it "does not raise" do
      expect { check }.not_to raise_error
      expect(Serega::SeregaValidations::CheckFormatter).not_to have_received(:call)
    end
  end

  context "with the name of an added formatter" do
    let(:format) { :money }

    it "does not raise" do
      expect { check }.not_to raise_error
      expect(Serega::SeregaValidations::CheckFormatter).not_to have_received(:call)
    end
  end

  context "with the name of a not added formatter" do
    let(:format) { :percent }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, "Formatter `:percent` was not defined"
    end
  end

  context "with a callable" do
    let(:format) { ->(value) { "#{value}%" } }

    it "checks the formatter" do
      check

      expect(Serega::SeregaValidations::CheckFormatter).to have_received(:call).with(:format, format)
    end
  end
end
