# frozen_string_literal: true

load_plugin_code(:root, :metadata)

RSpec.describe Serega::SeregaPlugins::Metadata::MetaAttribute::CheckBlock do
  let(:params_count_error) { "Block can have maximum two parameters (object(s), context)" }

  it "checks block has maximum 2 args" do
    expect { described_class.call(lambda {}) }.not_to raise_error
    expect { described_class.call(lambda { |obj| }) }.not_to raise_error
    expect { described_class.call(lambda { |obj, ctx| }) }.not_to raise_error
    expect { described_class.call(lambda { |obj, ctx, foo| }) }
      .to raise_error Serega::SeregaError, params_count_error
  end
end
