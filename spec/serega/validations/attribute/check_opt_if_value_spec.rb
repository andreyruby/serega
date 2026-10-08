# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptIfValue do
  subject(:check) { described_class.call(opts) }

  let(:opts) { {if_value: condition} }
  let(:must_be_callable) { "Invalid attribute option :if_value. It must be a Symbol, a Proc or respond to :call" }

  let(:signature_error) do
    <<~ERR.strip
      Invalid attribute option :if_value parameters, valid parameters signatures:
      - ()                     # no parameters
      - (value)                # one positional parameter
      - (value, context)       # two positional parameters
      - (value, :ctx)          # one positional parameter and :ctx keyword
      - (value, context, :ctx) # two positional parameters and :ctx keyword
    ERR
  end

  context "without the :if_value option" do
    let(:opts) { {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a Symbol" do
    let(:condition) { :present? }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with nil" do
    let(:condition) { nil }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, must_be_callable
    end
  end

  context "with a String" do
    let(:condition) { "present?" }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, must_be_callable
    end
  end

  context "with a callable object" do
    let(:condition) { Class.new { def self.call(value, context) = true } }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a condition without parameters" do
    let(:condition) { -> {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a condition with the value parameter" do
    let(:condition) { ->(value) {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a condition with the value and context parameters" do
    let(:condition) { ->(value, context) {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a condition with the value parameter and the ctx keyword" do
    let(:condition) { ->(value, ctx:) {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a condition with the value and context parameters and the ctx keyword" do
    let(:condition) { ->(value, context, ctx:) {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a condition with another keyword" do
    let(:condition) { ->(value, user:) {} }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, signature_error
    end
  end

  context "with the :serializer option" do
    let(:opts) { {if_value: :present?, serializer: "PostSerializer"} }

    it "raises an error" do
      expect { check }
        .to raise_error Serega::SeregaError, "Option :if_value can not be used together with option :serializer"
    end
  end
end
