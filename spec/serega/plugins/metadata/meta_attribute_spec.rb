# frozen_string_literal: true

load_plugin_code :root, :metadata

RSpec.describe Serega::SeregaPlugins::Metadata::MetaAttribute do
  let(:serializer) do
    Class.new(Serega) do
      plugin :root
      plugin :metadata
    end
  end

  describe "validations" do
    subject(:validate) { described_class.new(serializer, path: path, opts: opts, block: block) }

    let(:path) { ["PATH"] }
    let(:opts) { {foo: :bar} }
    let(:block) { proc {} }

    let(:serializer) do
      Class.new(Serega) do
        plugin :root
        plugin :metadata
      end
    end

    before do
      allow(Serega::SeregaPlugins::Metadata::MetaAttribute::CheckParams).to receive(:call)
    end

    it "validates path, opts, block" do
      validate

      expect(Serega::SeregaPlugins::Metadata::MetaAttribute::CheckParams)
        .to have_received(:call).with(path, opts, block, true)
    end

    context "when :check_attribute_name config option is false" do
      before { serializer.config.check_attribute_name = false }

      it "skips validating path" do
        validate

        expect(Serega::SeregaPlugins::Metadata::MetaAttribute::CheckParams)
          .to have_received(:call).with(path, opts, block, false)
      end
    end
  end

  describe "#value" do
    subject(:value) { described_class.new(serializer, path: ["path"], opts: opts, block: block).value(obj, ctx) }

    let(:opts) { {} }
    let(:block) { nil }
    let(:obj) { "OBJ" }
    let(:ctx) { "CTX" }

    context "when block as Proc provided" do
      let(:block) { proc { 123 } }

      it "returns provided block value" do
        expect(value).to eq 123
      end
    end

    context "when block as lambda with 0 args provided" do
      let(:block) { -> { "CONST" } }

      it "returns provided block value" do
        expect(value).to eq "CONST"
      end
    end

    context "when block as lambda with 1 arg provided" do
      let(:block) { ->(obj) { obj } }

      it "returns provided block value" do
        expect(value).to eq "OBJ"
      end
    end

    context "when block as lambda with 2 args provided" do
      let(:block) { ->(obj, ctx) { obj + ctx } }

      it "returns provided block value" do
        expect(value).to eq "OBJCTX"
      end
    end

    context "when :const option provided" do
      let(:opts) { {const: 1} }

      it "returns provided const value" do
        expect(value).to eq 1
      end
    end

    context "when :value option provided" do
      let(:opts) { {value: proc { |obj, ctx| obj + ctx }} }

      it "returns provided value proc result" do
        expect(value).to eq "OBJCTX"
      end
    end
  end

  describe "#hide?" do
    let(:attr) { described_class.new(serializer, path: ["path"], opts: opts, block: block) }
    let(:opts) { {} }
    let(:block) { proc {} }

    context "when no opts provided" do
      it "returns false" do
        expect(attr.hide?(nil)).to be false
      end
    end

    context "with :hide_nil set" do
      let(:opts) { {hide_nil: true} }

      it "returns true if value is nil" do
        expect(attr.hide?(nil)).to be true
        expect(attr.hide?("")).to be false
        expect(attr.hide?([])).to be false
        expect(attr.hide?({})).to be false
      end
    end

    context "with :hide_empty set" do
      let(:opts) { {hide_empty: true} }

      it "returns true if value is nil or empty" do
        expect(attr.hide?(nil)).to be true
        expect(attr.hide?("")).to be true
        expect(attr.hide?([])).to be true
        expect(attr.hide?({})).to be true
        expect(attr.hide?(" ")).to be false
        expect(attr.hide?(0)).to be false
      end
    end
  end

  describe "#nested_value" do
    subject(:nested_value) { attr.nested_value("OBJ", "CTX") }

    let(:attr) { described_class.new(serializer, path: %i[meta paging], opts: opts, block: block) }
    let(:opts) { {} }
    let(:block) { ->(obj, ctx) { [obj, ctx] } }

    it "returns the value nested under the path" do
      expect(nested_value).to eq(meta: {paging: ["OBJ", "CTX"]})
    end

    context "with a hidden value" do
      let(:opts) { {hide_nil: true} }
      let(:block) { proc {} }

      it "returns nil" do
        expect(nested_value).to be_nil
      end
    end
  end
end
