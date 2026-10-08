# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptUnless do
  subject(:check) { described_class.call(opts) }

  let(:opts) { {unless: condition} }
  let(:must_be_callable) { "Invalid attribute option :unless. It must be a Symbol, a Proc or respond to :call" }

  let(:signature_error) do
    <<~ERR.strip
      Invalid attribute option :unless parameters, valid parameters signatures:
      - ()                      # no parameters
      - (object)                # one positional parameter
      - (object, context)       # two positional parameters
      - (object, :ctx)          # one positional parameter and :ctx keyword
      - (object, context, :ctx) # two positional parameters and :ctx keyword
    ERR
  end

  context "without the :unless option" do
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
    let(:condition) { Class.new { def self.call(object, context) = true } }

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

  context "with a condition with the object parameter" do
    let(:condition) { ->(object) {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a condition with the object and context parameters" do
    let(:condition) { ->(object, context) {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a condition with the object parameter and the ctx keyword" do
    let(:condition) { ->(object, ctx:) {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a condition with the object and context parameters and the ctx keyword" do
    let(:condition) { ->(object, context, ctx:) {} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a condition with another keyword" do
    let(:condition) { ->(object, user:) {} }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, signature_error
    end
  end
end
