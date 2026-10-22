# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptCondition do
  subject(:check) { described_class.call(opts, name) }

  let(:name) { :if }
  let(:opts) { {name => condition} }
  let(:must_be_callable) { "Invalid attribute option :if. It must be a Symbol, a Proc or respond to :call" }

  let(:signature_error) do
    <<~ERR.strip
      Invalid attribute option :if parameters, valid parameters signatures:
      - ()
      - (object)
      - (object, context)
      - (object, :ctx)
      - (object, context, :ctx)
    ERR
  end

  context "without the option" do
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

  context "with the :serializer option" do
    let(:opts) { {if: :present?, serializer: "PostSerializer"} }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with the :if_value option" do
    let(:name) { :if_value }

    context "with a condition with another keyword" do
      let(:condition) { ->(value, user:) {} }

      it "raises an error that names the value parameter" do
        expect { check }.to raise_error Serega::SeregaError, <<~ERR.strip
          Invalid attribute option :if_value parameters, valid parameters signatures:
          - ()
          - (value)
          - (value, context)
          - (value, :ctx)
          - (value, context, :ctx)
        ERR
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

  context "with the :unless_value option and the :serializer option" do
    let(:name) { :unless_value }
    let(:opts) { {unless_value: :present?, serializer: "PostSerializer"} }

    it "raises an error" do
      expect { check }
        .to raise_error Serega::SeregaError, "Option :unless_value can not be used together with option :serializer"
    end
  end
end
