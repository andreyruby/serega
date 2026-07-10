# frozen_string_literal: true

load_plugin_code :explicit_many_option

RSpec.describe Serega::SeregaPlugins::ExplicitManyOption do
  let(:base_serializer) do
    Class.new(Serega) do
      plugin :explicit_many_option
    end
  end

  describe "Validations" do
    it "adds CheckOptMany validator" do
      allow(described_class::CheckOptMany).to receive(:call)
      base_serializer.attribute :foo, many: true, serializer: "foo"
      expect(described_class::CheckOptMany).to have_received(:call).with({many: true, serializer: "foo"}, nil)
    end

    it "adds CheckOptMany validator with provided block" do
      allow(described_class::CheckOptMany).to receive(:call)
      block = proc { attribute :text }
      base_serializer.attribute :comments, many: true, base_serializer: Serega, &block
      expect(described_class::CheckOptMany)
        .to have_received(:call).with({many: true, base_serializer: Serega}, block)
    end

    describe described_class::CheckOptMany do
      let(:error_message) do
        "Attribute option :many [Boolean] must be provided" \
          " for attributes with :serializer option or a block"
      end

      it "require to set :many option for attributes with serializer" do
        expect { described_class.call(serializer: "foo") }
          .to raise_error Serega::SeregaError, error_message
      end

      it "require to set :many option for attributes with block" do
        block = proc { attribute :text }
        expect { described_class.call({}, block) }
          .to raise_error Serega::SeregaError, error_message
      end

      it "does not require to set :many option for attributes without serializer and block" do
        expect { described_class.call({}) }.not_to raise_error
      end

      it "allows when :many option exists for attributes with serializer" do
        expect { described_class.call({serializer: "foo", many: false}) }.not_to raise_error
      end

      it "allows when :many option exists for attributes with block" do
        block = proc { attribute :text }
        expect { described_class.call({many: false}, block) }.not_to raise_error
      end
    end
  end
end
