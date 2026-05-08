# frozen_string_literal: true

load_plugin_code :if

RSpec.describe Serega::SeregaPlugins::If::CheckOptUnless do
  let(:must_be_callable) do
    "Invalid attribute option :unless. It must be a Symbol, a Proc or respond to :call"
  end

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

  it "prohibits non-proc, non-callable, non-symbol values" do
    expect { described_class.call(unless: nil) }.to raise_error Serega::SeregaError, must_be_callable
    expect { described_class.call(unless: "String") }.to raise_error Serega::SeregaError, must_be_callable
    expect { described_class.call(unless: []) }.to raise_error Serega::SeregaError, must_be_callable
    expect { described_class.call(unless: {}) }.to raise_error Serega::SeregaError, must_be_callable
    expect { described_class.call(unless: Object) }.to raise_error Serega::SeregaError, must_be_callable
    expect { described_class.call(unless: Object.new) }.to raise_error Serega::SeregaError, must_be_callable
  end

  it "checks callable parameters signature" do
    expect { described_class.call(unless: proc {}) }.not_to raise_error
    expect { described_class.call(unless: lambda {}) }.not_to raise_error
    expect { described_class.call(unless: lambda { |obj| }) }.not_to raise_error
    expect { described_class.call(unless: lambda { |obj, ctx| }) }.not_to raise_error
    expect { described_class.call(unless: lambda { |obj, ctx:| }) }.not_to raise_error
    expect { described_class.call(unless: lambda { |foo:| }) }.to raise_error Serega::SeregaError, signature_error
  end

  it "allows symbols" do
    expect { described_class.call(unless: :foo) }.not_to raise_error
  end
end
