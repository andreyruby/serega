# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckBlock do
  let(:block) { nil }
  let(:signature_error) do
    <<~ERR.strip
      Invalid attribute block parameters, valid parameters signatures:
      - ()                       # no parameters
      - (object)                 # one positional parameter
      - (object, ctx:)           # one positional parameter and :ctx keyword
      - (object, batches:)       # one positional parameter and :batches keyword
      - (object, ctx:, batches:) # one positional parameter, :ctx, and :batches keywords
      - (object, context)        # two positional parameters
    ERR
  end

  it "allows no block" do
    expect { described_class.call(nil) }.not_to raise_error
  end

  it "checks block parameters signature" do
    expect { described_class.call(lambda {}) }.not_to raise_error
    expect { described_class.call(lambda { |obj| }) }.not_to raise_error
    expect { described_class.call(lambda { |obj, ctx| }) }.not_to raise_error
    expect { described_class.call(lambda { |obj, ctx:| }) }.not_to raise_error
    expect { described_class.call(lambda { |obj, ctx: {}| }) }.not_to raise_error
    expect { described_class.call(lambda { |obj, batches:| }) }.not_to raise_error
    expect { described_class.call(lambda { |obj, ctx:, batches:| }) }.not_to raise_error
    expect { described_class.call(lambda { |obj, context, ctx:| }) }
      .to raise_error Serega::SeregaError, signature_error
  end
end
