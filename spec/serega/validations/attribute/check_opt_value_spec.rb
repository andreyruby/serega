# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptValue do
  subject(:check) { described_class.call(opts) }

  let(:opts) { {} }

  let(:type_error) { "Option :value value must be a Proc or respond to #call" }
  let(:signature_error) do
    <<~ERROR.strip
      Invalid attribute :value option parameters, valid parameters signatures:
      - ()                       # no parameters
      - (object)                 # one positional parameter
      - (object, ctx:)           # one positional parameter and :ctx keyword
      - (object, batches:)       # one positional parameter and :batches keyword
      - (object, ctx:, batches:) # one positional parameter, :ctx, and :batches keywords
      - (object, context)        # two positional parameters
    ERROR
  end

  it "allows no :value option" do
    opts[:foo] = nil
    expect { check }.not_to raise_error
  end

  it "allows :value option with proc" do
    opts[:value] = proc {}
    expect { check }.not_to raise_error
  end

  it "allows :value option with callable object" do
    callable = Class.new do
      def call
      end
    end.new
    opts[:value] = callable
    expect { check }.not_to raise_error
  end

  it "raises error when :value is not a proc or callable" do
    opts[:value] = 123
    expect { check }.to raise_error Serega::SeregaError, "Option :value value must be a Proc or respond to #call"
  end

  context "with method signatures" do
    it "allows no parameters" do
      opts[:value] = proc {}
      expect { check }.not_to raise_error
    end

    it "allows one parameter" do
      opts[:value] = proc { |obj| }
      expect { check }.not_to raise_error
    end

    it "allows one parameter with :ctx keyword" do
      opts[:value] = proc { |obj, ctx:| }
      expect { check }.not_to raise_error
    end

    it "allows one parameter with :batches keyword" do
      opts[:value] = proc { |obj, batches:| }
      expect { check }.not_to raise_error
    end

    it "allows one parameter with both :ctx and :batches keywords" do
      opts[:value] = proc { |obj, ctx:, batches:| }
      expect { check }.not_to raise_error
    end

    it "allows two parameters" do
      opts[:value] = proc { |obj, context| }
      expect { check }.not_to raise_error
    end

    it "raises error with invalid signature" do
      opts[:value] = lambda { |a, b, c| }
      expect { check }.to raise_error Serega::SeregaError, signature_error
    end
  end

  context "with other options" do
    it "prohibits to use with :method opt" do
      opts.merge!(value: proc {}, method: :name)
      expect { check }.to raise_error Serega::SeregaError, "Option :value can not be used together with option :method"
    end

    it "prohibits to use with :const opt" do
      opts.merge!(value: proc {}, const: 1)
      expect { check }.to raise_error Serega::SeregaError, "Option :value can not be used together with option :const"
    end
  end

  it "checks keyword value" do
    expect { described_class.call({value: :value}) }
      .to raise_error Serega::SeregaError, type_error
  end
end
