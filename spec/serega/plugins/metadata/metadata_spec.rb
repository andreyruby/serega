# frozen_string_literal: true

load_plugin_code :root, :metadata

RSpec.describe Serega::SeregaPlugins::Metadata do
  let(:serializer) { Class.new(Serega) { plugin :root } }

  describe "loading" do
    it "raises error when root plugin was not added before" do
      expect { Class.new(Serega) { plugin :metadata } }
        .to raise_error Serega::SeregaError, "Plugin :metadata must be loaded after the :root plugin. Please load the :root plugin first"
    end
  end

  describe "block-defined nested serializer" do
    it "does not receive meta attributes when the base serializer has none" do
      base = Class.new(serializer) { plugin :metadata }.freeze
      parent = Class.new(base)
      parent.config.base_serializer = base
      parent.meta_attribute(:version, const: "1.2.3")
      parent.attribute(:profile, method: :itself) { attribute :bio }

      nested = parent.attributes[:profile].serializer
      expect(nested.plugin_used?(:metadata)).to be true
      expect(nested.meta_attributes).to be_empty
    end
  end

  describe "inheritance" do
    let(:parent) { Class.new(serializer) { plugin :metadata } }
    let(:child) { Class.new(parent) }

    it "inherits MetaAttribute class" do
      expect(parent::MetaAttribute).to be child::MetaAttribute.superclass
    end

    it "inherits meta attributes" do
      parent_attr = parent.meta_attribute(:version, hide_nil: true) { "1.2.3" }

      expect(child.meta_attributes.length).to eq 1
      child_attr = child.meta_attributes[:version]
      expect(child_attr).not_to equal parent_attr
      expect(child_attr.opts).to eq(hide_nil: true)
      expect(child_attr.path).to eq([:version])
      expect(child_attr.block).to equal parent_attr.block
      expect(child_attr.value(nil, nil)).to eq "1.2.3"
    end

    it "allows to override meta attributes" do
      parent.meta_attribute(:version, :minor) { "1" }
      child_attr = child.meta_attributes[:"version.minor"]

      expect(child.meta_attributes.length).to eq 1
      expect(child_attr.value(nil, nil)).to eq "1"

      child.meta_attribute(:version, :minor) { "2" }
      expect(child.meta_attributes.length).to eq 1

      child_attr = child.meta_attributes[:"version.minor"]
      expect(child_attr.value(nil, nil)).to eq "2"
    end
  end

  describe "serialization" do
    subject(:response) { user_serializer.to_h(obj, context: context) }

    let(:obj) { double(first_name: "FIRST_NAME") }
    let(:context) { {} }
    let(:base_serializer) { Class.new(serializer) { plugin :metadata } }

    let(:user_serializer) do
      Class.new(base_serializer) do
        attribute :first_name
      end
    end

    context "with regular metadata with single object" do
      before do
        user_serializer.meta_attribute(:version, const: "1.2.3")
        user_serializer.freeze
      end

      it "appends metadata attributes to response" do
        expect(response).to eq(data: {first_name: "FIRST_NAME"}, version: "1.2.3")
      end
    end

    context "with regular metadata with multiple objects" do
      let(:obj) { [double(first_name: "FIRST_NAME")] }

      before do
        user_serializer.meta_attribute(:version, const: "1.2.3")
        user_serializer.freeze
      end

      it "appends metadata attributes to response" do
        expect(response).to eq(data: [{first_name: "FIRST_NAME"}], version: "1.2.3")
      end
    end

    context "with metadata with parameters" do
      let(:context) { {page: 2, per_page: 3} }

      let(:block) do
        proc do |obj, context|
          {
            total_count: Array(obj).size,
            page: context[:page],
            per_page: context[:per_page]
          }
        end
      end

      before do
        user_serializer.meta_attribute(:meta, :paging, value: block)
        user_serializer.freeze
      end

      it "appends metadata attributes to response" do
        expect(response).to eq(
          data: {first_name: "FIRST_NAME"},
          meta: {paging: {total_count: 1, page: 2, per_page: 3}}
        )
      end
    end

    describe "merging multiple metadata attributes" do
      let(:context) { {page: 2, per_page: 3} }

      before do
        user_serializer.meta_attribute(:version, :number, const: "1.2.3")
        user_serializer.meta_attribute(:version, const: "1.2.3")
        user_serializer.meta_attribute(:meta, :paging, :total_count) { |obj| Array(obj).count }
        user_serializer.meta_attribute(:meta, :paging, :page) { |_obj, ctx| ctx[:page] }
        user_serializer.meta_attribute(:meta, :paging, :per_page) { |_obj, ctx| ctx[:per_page] }
        user_serializer.freeze
      end

      it "appends merged metadata attributes to response" do
        expect(response).to eq(
          data: {first_name: "FIRST_NAME"},
          version: "1.2.3",
          meta: {
            paging: {
              total_count: 1, page: 2, per_page: 3
            }
          }
        )
      end
    end

    context "when a meta attribute returns a Hash" do
      let(:paging) { {page: 2} }

      before do
        paging_value = paging
        user_serializer.meta_attribute(:meta, :paging) { paging_value }
        user_serializer.meta_attribute(:meta, :paging, :per_page) { 3 }
        user_serializer.freeze
      end

      it "merges other metadata without changing the returned Hash" do
        expect(response).to eq(data: {first_name: "FIRST_NAME"}, meta: {paging: {page: 2, per_page: 3}})
        expect(paging).to eq(page: 2)
      end
    end

    describe "when metadata block raises error" do
      let(:context) { {page: 2, per_page: 3} }

      before do
        user_serializer.meta_attribute(:version, :number) { foo }
        user_serializer.freeze
      end

      it "raises error and additionally shows meta_attribute path" do
        expect { response }.to raise_error NameError,
          end_with("(when serializing meta_attribute [:version, :number] in #{user_serializer})")
      end
    end

    describe "hiding metadata attributes" do
      let(:context) { {page: 2, per_page: 3} }

      before do
        user_serializer.meta_attribute(:meta, :test1, hide_nil: true) {}
        user_serializer.meta_attribute(:meta, :test2, hide_empty: true) { {} }
        user_serializer.meta_attribute(:meta, :test3, hide_empty: true) { [] }
        user_serializer.meta_attribute(:meta, :test4, hide_empty: true) { "" }
        user_serializer.meta_attribute(:meta, :test5) { nil }
        user_serializer.meta_attribute(:meta, :test6) { {} }
        user_serializer.meta_attribute(:meta, :test7) { [] }
        user_serializer.meta_attribute(:meta, :test8, hide_nil: true, hide_empty: true) { "foo" }
        user_serializer.freeze
      end

      it "hides empty or nil attributes when :hide_nil / :hide_empty options provided" do
        expect(response).to eq(
          data: {first_name: "FIRST_NAME"},
          meta: {
            test5: nil,
            test6: {},
            test7: [],
            test8: "foo"
          }
        )
      end
    end

    context "when root is nil" do
      before do
        user_serializer.config.root = {one: nil, many: nil}
        user_serializer.meta_attribute(:version, const: "1.2.3")
        user_serializer.freeze
      end

      it "does not add metadata" do
        expect(user_serializer.to_h(obj)).to eq({first_name: "FIRST_NAME"})
        expect(user_serializer.to_h([obj])).to eq([{first_name: "FIRST_NAME"}])
      end
    end
  end

  describe "serialization to data" do
    subject(:result) { user_serializer.to_data(user) }

    let(:user_serializer) do
      Class.new(serializer) do
        plugin :metadata
        attribute :first_name
        meta_attribute(:version, const: "1.2.3")
        meta_attribute(:meta, :paging, :page, const: 1)
        freeze
      end
    end

    let(:user) { double(first_name: "FIRST_NAME") }

    it "adds metadata to the result Hash as it is" do
      expect(result.keys).to eq %i[data version meta]
      expect(result[:data].to_h).to eq(first_name: "FIRST_NAME")
      expect(result[:version]).to eq "1.2.3"
      expect(result[:meta]).to eq(paging: {page: 1})
    end
  end

  describe "serialization to structs" do
    subject(:result) { user_serializer.to_struct(user) }

    let(:user_serializer) do
      Class.new(serializer) do
        plugin :metadata
        attribute :first_name
        meta_attribute(:version, const: "1.2.3")
        meta_attribute(:meta, :paging, :page, const: 1)
        freeze
      end
    end

    let(:user) { double(first_name: "FIRST_NAME") }

    it "adds metadata to the result Hash as it is" do
      expect(result.keys).to eq %i[data version meta]
      expect(result[:data]).to be_a(Struct)
      expect(result[:data].to_h).to eq(first_name: "FIRST_NAME")
      expect(result[:version]).to eq "1.2.3"
      expect(result[:meta]).to eq(paging: {page: 1})
    end
  end

  describe "prepare_initial_objects" do
    it "provides prepared objects to metadata attributes" do
      records = {"1" => double(first_name: "Ann"), "2" => double(first_name: "Bob")}
      user_serializer = Class.new(Serega) do
        plugin :root
        plugin :metadata
        prepare_initial_objects { |ids| ids.map { |id| records[id] } }
        attribute :first_name
        meta_attribute(:total) { |objects| objects.size }
        freeze
      end

      expect(user_serializer.to_h(["1", "2"])).to eq(
        data: [{first_name: "Ann"}, {first_name: "Bob"}],
        total: 2
      )
    end
  end

  context "when the config is deeply frozen", if: defined?(Ractor) do
    let(:frozen_config) do
      serializer_class = Class.new(Serega) do
        plugin :root
        plugin :metadata
      end
      Ractor.make_shareable(serializer_class.config)
    end

    it "returns the metadata config" do
      expect(frozen_config.metadata).to be_a Serega::SeregaPlugins::Metadata::MetadataConfig
    end
  end
end
