# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptHashAccess do
  subject(:check) { described_class.call(opts) }

  let(:opts) { {hash_access: true} }

  before do
    allow(Serega::SeregaValidations::Utils::CheckHashAccessValue).to receive(:call)
  end

  it "checks the option value" do
    check

    expect(Serega::SeregaValidations::Utils::CheckHashAccessValue).to have_received(:call).with(opts, :hash_access)
  end

  context "with the :delegate option" do
    let(:opts) { {hash_access: true, delegate: {to: :address}} }

    it "raises an error that points to the delegate sub-options" do
      expect { check }.to raise_error Serega::SeregaError,
        "Option :hash_access can not be used together with option :delegate." \
        " Use the delegate :to_hash_access (intermediate step) and" \
        " :hash_access (final step) sub-options instead"
    end
  end

  context "with hash_access: false and the :delegate option" do
    let(:opts) { {hash_access: false, delegate: {to: :address}} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end
end
