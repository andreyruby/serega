# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::CheckFormatter do
  subject(:check) { described_class.call(:money, formatter) }

  let(:signature_error) do
    <<~ERR.strip
      Invalid formatter parameters, valid parameters signatures:
      - (value)          # one positional parameter
      - (value, context) # two positional parameters
      - (value, :ctx)    # one positional parameter and :ctx keyword
    ERR
  end

  context "with a value parameter" do
    let(:formatter) { ->(cents) {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with value and context parameters" do
    let(:formatter) { ->(cents, context) {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a value parameter and the :ctx keyword" do
    let(:formatter) { ->(cents, ctx:) {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a not callable formatter" do
    let(:formatter) { "round" }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, "Option :money must have callable value"
    end
  end

  context "without parameters" do
    let(:formatter) { -> {} }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, signature_error
    end
  end
end
