# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::CheckFormatter do
  subject(:check) { described_class.call(formatter_name, formatter) }

  let(:formatter_name) { :money }

  let(:invalid_formatter) do
    <<~ERR.strip
      Invalid formatter :money. A formatter must be one of:
      - a callable, for example ->(value) { value.round(2) }
      - a method name, for example :to_s
      - an Array of a method name and its arguments, for example [:round, 2]
    ERR
  end

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

  context "without parameters" do
    let(:formatter) { -> {} }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, signature_error
    end
  end

  context "with a method name" do
    let(:formatter) { :to_s }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with a method name and arguments" do
    let(:formatter) { [:round, 2] }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with an Array without a method name" do
    let(:formatter) { ["round", 2] }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, invalid_formatter
    end
  end

  context "with a Hash" do
    let(:formatter) { {use: [:round, 2], allow_nil: true} }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, invalid_formatter
    end
  end

  context "with a String" do
    let(:formatter) { "round" }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, invalid_formatter
    end
  end

  context "with the attribute :format option" do
    let(:formatter_name) { nil }

    let(:invalid_format_option) do
      <<~ERR.strip
        Invalid attribute option :format. It must be a formatter name or one of:
        - a callable, for example ->(value) { value.round(2) }
        - an Array of a method name and its arguments, for example [:round, 2]
        - a Hash with one of them or a method name as :use and the :allow_nil option, for example {use: :to_s, allow_nil: true}
      ERR
    end

    context "with a Hash" do
      let(:formatter) { {use: [:round, 2], allow_nil: true} }

      it "does not raise" do
        expect { check }.not_to raise_error
      end
    end

    context "with a Hash with a not allowed key" do
      let(:formatter) { {use: :to_s, skip_nil: true} }

      it "raises an error" do
        expect { check }
          .to raise_error Serega::SeregaError, "Invalid formatter option :skip_nil. Allowed options are: :allow_nil, :use"
      end
    end

    context "with a Hash with a not boolean :allow_nil" do
      let(:formatter) { {use: :to_s, allow_nil: 1} }

      it "raises an error" do
        expect { check }.to raise_error Serega::SeregaError, "Invalid option :allow_nil => 1. Must have a boolean value"
      end
    end

    context "with a Hash without :use" do
      let(:formatter) { {allow_nil: true} }

      it "raises an error" do
        expect { check }.to raise_error Serega::SeregaError, invalid_format_option
      end
    end

    context "with a String" do
      let(:formatter) { "round" }

      it "raises an error" do
        expect { check }.to raise_error Serega::SeregaError, invalid_format_option
      end
    end
  end
end
