# frozen_string_literal: true

load_plugin_code :root, :context_metadata

RSpec.describe Serega::SeregaPlugins::ContextMetadata do
  let(:serializer) { Class.new(Serega) { plugin :root } }

  describe "loading" do
    it "adds default :context_metadata_key config option" do
      serializer.plugin :context_metadata
      expect(serializer.config.context_metadata.key).to eq :meta
    end

    it "adds specified :context_metadata_key config option" do
      serializer.plugin :context_metadata, context_metadata_key: :metadata
      expect(serializer.config.context_metadata.key).to eq :metadata
    end

    it "raises error when root plugin was not added before" do
      expect { Class.new(Serega) { plugin :context_metadata } }
        .to raise_error Serega::SeregaError, "Plugin :context_metadata must be loaded after the :root plugin. Please load the :root plugin first"
    end

    it "raises error if plugin defined with unknown option" do
      serializer = Class.new(Serega)
      expect { serializer.plugin(:context_metadata, foo: :bar) }
        .to raise_error Serega::SeregaError, <<~MESSAGE.strip
          Plugin :context_metadata does not accept the :foo option. Allowed options:
            - :context_metadata_key [Symbol] - The key name that must be used to add metadata. Default is :meta.
        MESSAGE
    end
  end

  describe "configuration" do
    it "allows to change context_metadata key config option" do
      serializer.plugin :context_metadata

      context_metadata = serializer.config.context_metadata
      context_metadata.key = :foo
      expect(serializer.config.context_metadata.key).to eq :foo
    end

    it "preserves context_metadata" do
      serializer.plugin :context_metadata
      context_metadata1 = serializer.config.context_metadata
      context_metadata2 = serializer.config.context_metadata
      expect(context_metadata1).to be context_metadata2
    end
  end

  describe "validations" do
    it "raises error when default context meta key is not a Hash" do
      serializer.plugin :context_metadata
      expect { serializer.to_h(nil, meta: []) }
        .to raise_error Serega::SeregaError, "Invalid option :meta => []. Must have a Hash value"
    end

    it "raises error when configured context meta key is not a Hash" do
      serializer.plugin :context_metadata, context_metadata_key: :foo
      expect { serializer.to_h(nil, foo: []) }
        .to raise_error Serega::SeregaError, "Invalid option :foo => []. Must have a Hash value"
    end
  end

  describe "serialization" do
    subject(:response) { user_serializer.to_h(obj, **opts) }

    let(:obj) { double(first_name: "FIRST_NAME") }
    let(:opts) { {meta: {version: "1.2.3"}} }
    let(:base_serializer) { Class.new(serializer) { plugin :context_metadata } }
    let(:user_serializer) do
      Class.new(base_serializer) do
        attribute :first_name
      end
    end

    context "with single object" do
      it "appends metadata attributes to response" do
        expect(response).to eq(data: {first_name: "FIRST_NAME"}, version: "1.2.3")
      end
    end

    context "with multiple objects" do
      let(:obj) { [double(first_name: "FIRST_NAME")] }

      it "appends metadata attributes to response" do
        expect(response).to eq(data: [{first_name: "FIRST_NAME"}], version: "1.2.3")
      end
    end

    context "when setting metadata key to nil" do
      before do
        user_serializer.config.context_metadata.key = nil
      end

      it "skips adding metadata to response" do
        expect(response).to eq(data: {first_name: "FIRST_NAME"})
      end
    end

    context "when metadata is not added" do
      let(:opts) { {} }

      it "skips adding any metadata to response" do
        expect(response).to eq(data: {first_name: "FIRST_NAME"})
      end
    end

    context "with :metadata plugin" do
      let(:serializer) do
        Class.new(Serega) do
          plugin :root
          plugin :metadata
          plugin :context_metadata

          meta_attribute(:foo, :one) { 1 }
          meta_attribute(:foo, :two) { 2 }
        end
      end

      it "merges metadata" do
        opts = {meta: {foo: {two: "two", three: "three"}}}
        response = serializer.to_h([], **opts)
        expect(response).to eq(
          data: [],
          foo: {one: 1, two: "two", three: "three"}
        )
      end
    end

    context "when root is nil" do
      before do
        user_serializer.config.root = {one: nil, many: nil}
      end

      it "does not add metadata" do
        expect(user_serializer.to_h(obj, meta: {version: "1.2.3"})).to eq({first_name: "FIRST_NAME"})
        expect(user_serializer.to_h([obj], meta: {version: "1.2.3"})).to eq([{first_name: "FIRST_NAME"}])
      end
    end
  end

  describe "serialization to data" do
    let(:obj) { double(first_name: "FIRST_NAME") }
    let(:base_serializer) { Class.new(serializer) { plugin :context_metadata } }
    let(:user_serializer) do
      Class.new(base_serializer) do
        attribute :first_name
      end
    end

    it "wraps data under root key and keeps context metadata as plain values" do
      result = user_serializer.to_data(obj, meta: {version: "1.2.3"})
      expect(result).to be_a Data
      expect(result.members).to contain_exactly(:data, :version)
      expect(result.data.first_name).to eq "FIRST_NAME"
      expect(result.version).to eq "1.2.3"
    end

    it "works with a collection" do
      result = user_serializer.to_data([obj], meta: {version: "1.2.3"})
      expect(result.members).to contain_exactly(:data, :version)
      expect(result.data.first.first_name).to eq "FIRST_NAME"
    end

    it "returns plain Data without metadata when root is nil" do
      user_serializer.config.root = {one: nil, many: nil}
      result = user_serializer.to_data(obj, meta: {version: "1.2.3"})
      expect(result.members).to eq [:first_name]
    end

    it "converts nested context metadata hashes to Data objects" do
      result = user_serializer.to_data(obj, meta: {paging: {page: 1, per_page: 10}})
      expect(result.members).to contain_exactly(:data, :paging)
      expect(result.paging).to be_a Data
      expect(result.paging.page).to eq 1
      expect(result.paging.per_page).to eq 10
    end
  end
end
