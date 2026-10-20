# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::CheckSerializeKeywords do
  subject(:check) { described_class.call(context, many) }

  let(:context) { {current_user: "Ann"} }
  let(:many) { true }

  it "accepts a Hash context and a boolean many" do
    expect { check }.not_to raise_error
  end

  context "without a context and many" do
    let(:context) { nil }
    let(:many) { nil }

    it "accepts them" do
      expect { check }.not_to raise_error
    end
  end

  context "with a false many" do
    let(:many) { false }

    it "accepts it" do
      expect { check }.not_to raise_error
    end
  end

  context "with a context that is not a Hash" do
    let(:context) { [:current_user] }

    it "raises an error that names the option and its value" do
      expect { check }
        .to raise_error Serega::SeregaError, "Invalid option :context => [:current_user]. Must have a Hash value"
    end
  end

  context "with a many that is not a boolean" do
    let(:many) { "true" }

    it "raises an error that names the option and its value" do
      expect { check }
        .to raise_error Serega::SeregaError, 'Invalid option :many => "true". Must have a boolean value'
    end
  end
end
