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
      before { user_serializer.meta_attribute(:version, const: "1.2.3") }

      it "appends metadata attributes to response" do
        expect(response).to eq(data: {first_name: "FIRST_NAME"}, version: "1.2.3")
      end
    end

    context "with regular metadata with multiple objects" do
      let(:obj) { [double(first_name: "FIRST_NAME")] }

      before { user_serializer.meta_attribute(:version, const: "1.2.3") }

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

    describe "when metadata block raises error" do
      let(:context) { {page: 2, per_page: 3} }

      before do
        user_serializer.meta_attribute(:version, :number) { foo }
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
      end

      it "does not add metadata" do
        expect(user_serializer.to_h(obj)).to eq({first_name: "FIRST_NAME"})
        expect(user_serializer.to_h([obj])).to eq([{first_name: "FIRST_NAME"}])
      end
    end
  end

  describe "serialization to data" do
    let(:obj) { double(first_name: "FIRST_NAME") }
    let(:base_serializer) { Class.new(serializer) { plugin :metadata } }
    let(:user_serializer) do
      Class.new(base_serializer) do
        attribute :first_name
      end
    end

    before { user_serializer.meta_attribute(:version, const: "1.2.3") }

    it "wraps data under root key and keeps metadata as plain values" do
      result = user_serializer.to_data(obj)
      expect(result).to be_a Data
      expect(result.members).to contain_exactly(:data, :version)
      expect(result.data.first_name).to eq "FIRST_NAME"
      expect(result.version).to eq "1.2.3"
    end

    it "works with a collection" do
      result = user_serializer.to_data([obj])
      expect(result.members).to contain_exactly(:data, :version)
      expect(result.data).to be_an Array
      expect(result.data.first.first_name).to eq "FIRST_NAME"
      expect(result.version).to eq "1.2.3"
    end

    it "returns plain Data without metadata when root is nil" do
      user_serializer.config.root = {one: nil, many: nil}
      result = user_serializer.to_data(obj)
      expect(result.members).to eq [:first_name]
    end

    it "converts nested metadata hashes to Data objects" do
      user_serializer.meta_attribute(:meta, :paging, :page, const: 1)
      user_serializer.meta_attribute(:meta, :paging, :per_page, const: 10)
      result = user_serializer.to_data(obj)
      expect(result.members).to contain_exactly(:data, :version, :meta)
      expect(result.meta).to be_a Data
      expect(result.meta.paging).to be_a Data
      expect(result.meta.paging.page).to eq 1
      expect(result.meta.paging.per_page).to eq 10
    end

    it "converts hashes inside metadata arrays to Data objects" do
      user_serializer.meta_attribute(:links, const: [{href: "/prev", rel: "prev"}, {href: "/next", rel: "next"}])
      result = user_serializer.to_data(obj)
      expect(result.links).to be_an Array
      expect(result.links.first).to be_a Data
      expect(result.links.first.href).to eq "/prev"
      expect(result.links.first.rel).to eq "prev"
      expect(result.links.last.href).to eq "/next"
    end
  end
end
