# frozen_string_literal: true

load_plugin_code :if

RSpec.describe Serega::SeregaPlugins::If::CheckOptUnlessValue do
  let(:must_be_callable) do
    "Invalid attribute option :unless_value. It must be a Symbol, a Proc or respond to :call"
  end

  let(:signature_error) do
    <<~ERR.strip
      Invalid attribute option :unless_value parameters, valid parameters signatures:
      - ()                     # no parameters
      - (value)                # one positional parameter
      - (value, context)       # two positional parameters
      - (value, :ctx)          # one positional parameter and :ctx keyword
      - (value, context, :ctx) # two positional parameters and :ctx keyword
    ERR
  end

  let(:no_serializer) do
    "Option :unless_value can not be used together with option :serializer"
  end

  it "prohibits to use together with serializer option" do
    expect { described_class.call(unless_value: :foo, serializer: :foo) }.to raise_error Serega::SeregaError, no_serializer
  end

  it "prohibits non-proc, non-callable, non-symbol values" do
    expect { described_class.call(unless_value: nil) }.to raise_error Serega::SeregaError, must_be_callable
    expect { described_class.call(unless_value: "String") }.to raise_error Serega::SeregaError, must_be_callable
    expect { described_class.call(unless_value: []) }.to raise_error Serega::SeregaError, must_be_callable
    expect { described_class.call(unless_value: {}) }.to raise_error Serega::SeregaError, must_be_callable
    expect { described_class.call(unless_value: Object) }.to raise_error Serega::SeregaError, must_be_callable
    expect { described_class.call(unless_value: Object.new) }.to raise_error Serega::SeregaError, must_be_callable
  end

  it "checks callable parameters signature" do
    expect { described_class.call(unless_value: proc {}) }.not_to raise_error
    expect { described_class.call(unless_value: lambda {}) }.not_to raise_error
    expect { described_class.call(unless_value: lambda { |obj| }) }.not_to raise_error
    expect { described_class.call(unless_value: lambda { |obj, ctx| }) }.not_to raise_error
    expect { described_class.call(unless_value: lambda { |obj, ctx:| }) }.not_to raise_error
    expect { described_class.call(unless_value: lambda { |foo:| }) }.to raise_error Serega::SeregaError, signature_error
  end

  it "allows symbols" do
    expect { described_class.call(unless_value: :foo) }.not_to raise_error
  end
end
