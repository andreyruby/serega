# frozen_string_literal: true

load_plugin_code(:root, :metadata)

RSpec.describe Serega::SeregaPlugins::Metadata::MetaAttribute::CheckParams do
  subject(:check) { described_class.call(path, opts, block, check_path) }

  let(:path) { %i[meta paging] }
  let(:opts) { {hide_nil: true} }
  let(:block) { proc { |records, ctx| } }
  let(:check_path) { true }

  it "does not raise" do
    expect { check }.not_to raise_error
  end

  context "with a path key with other characters" do
    let(:path) { [:meta, "page count"] }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError,
        %(Invalid metadata path "page count". Allowed characters: "a-z", "A-Z", "0-9", "_", "-", "~")
    end
  end

  context "with a path key with other characters and the path check off" do
    let(:path) { [:meta, "page count"] }
    let(:check_path) { false }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with path keys of letters, digits, _, - and ~" do
    let(:path) { ["aZ09", "_-~", :foo_bar] }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with an unknown option" do
    let(:opts) { {foo: :bar} }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError,
        "Invalid meta_attribute option :foo. Allowed options are: :const, :hide_empty, :hide_nil, :value"
    end
  end

  context "with hide_nil: false" do
    let(:opts) { {hide_nil: false} }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, "Invalid option :hide_nil => false. Must be true"
    end
  end

  context "with hide_empty: nil" do
    let(:opts) { {hide_empty: nil} }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, "Invalid option :hide_empty => nil. Must be true"
    end
  end

  context "with the :const option" do
    let(:opts) { {const: 1} }
    let(:block) { nil }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with the :value option" do
    let(:opts) { {value: ->(records, ctx) {}} }
    let(:block) { nil }

    it "does not raise" do
      expect { check }.not_to raise_error
    end
  end

  context "with the :value and :const options" do
    let(:opts) { {value: -> {}, const: 1} }
    let(:block) { nil }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, "Option :value can not be used together with option :const"
    end
  end

  context "with the :value option and a block" do
    let(:opts) { {value: -> {}} }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, "Option :value can not be used together with block"
    end
  end

  context "with the :const option and a block" do
    let(:opts) { {const: 1} }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, "Option :const can not be used together with block"
    end
  end

  context "without a value, a const or a block" do
    let(:block) { nil }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, "Please provide block argument or add :value or :const option"
    end
  end

  context "with a :value that is not callable" do
    let(:opts) { {value: :count} }
    let(:block) { nil }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, "Option :value value must be a Proc or respond to #call"
    end
  end

  context "with a :value with three parameters" do
    let(:opts) { {value: ->(records, ctx, other) {}} }
    let(:block) { nil }

    it "raises an error" do
      expect { check }
        .to raise_error Serega::SeregaError, "Option :value value can have maximum 2 parameters (object(s), context)"
    end
  end

  context "with a block with three parameters" do
    let(:block) { proc { |records, ctx, other| } }

    it "raises an error" do
      expect { check }.to raise_error Serega::SeregaError, "Block can have maximum two parameters (object(s), context)"
    end
  end
end
