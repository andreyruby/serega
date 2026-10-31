# frozen_string_literal: true

RSpec.describe Serega::AttributeNormalizers::Preloads do
  subject(:preloads) { described_class.call(opts, relation, method_name, serializer_class.config) }

  let(:serializer_class) { Class.new(Serega) }
  let(:opts) { {} }
  let(:relation) { false }
  let(:method_name) { :author }

  it "returns nil" do
    expect(preloads).to be_nil
  end

  context "with the :preload option" do
    let(:opts) { {preload: {posts: [:comments, {likes: :user}]}} }

    it "returns the option as given" do
      expect(preloads).to eq(posts: [:comments, {likes: :user}])
    end
  end

  context "with an empty :preload option" do
    let(:opts) { {preload: []} }

    it "returns the option as given" do
      expect(preloads).to eq([])
    end
  end

  context "with preload: false" do
    let(:serializer_class) { Class.new(Serega) { config.auto_preload = true } }
    let(:opts) { {preload: false, serializer: "AuthorSerializer"} }

    it "returns nil" do
      expect(preloads).to be_nil
    end
  end

  context "with a relation" do
    let(:relation) { true }

    it "returns nil" do
      expect(preloads).to be_nil
    end
  end

  context "with the :delegate option" do
    let(:opts) { {delegate: {to: :profile}} }

    it "returns nil" do
      expect(preloads).to be_nil
    end
  end

  context "when auto preload has the serializer option" do
    let(:serializer_class) { Class.new(Serega) { config.auto_preload = {has_serializer_option: true} } }

    context "with a relation" do
      let(:relation) { true }

      it "returns the method name" do
        expect(preloads).to eq :author
      end
    end

    context "with a relation and the :batch option" do
      let(:relation) { true }
      let(:opts) { {batch: :authors} }

      it "returns nil" do
        expect(preloads).to be_nil
      end
    end

    context "with a relation and an excluded method" do
      let(:relation) { true }
      let(:method_name) { :itself }

      it "returns nil" do
        expect(preloads).to be_nil
      end
    end

    context "with only the :method option" do
      let(:opts) { {method: :profile} }

      it "returns nil" do
        expect(preloads).to be_nil
      end
    end
  end

  context "when auto preload has the delegate option" do
    let(:serializer_class) { Class.new(Serega) { config.auto_preload = {has_delegate_option: true} } }

    context "with the :delegate option" do
      let(:opts) { {delegate: {to: :profile}} }

      it "returns the delegated method name" do
        expect(preloads).to eq :profile
      end
    end

    context "with the :delegate option to an excluded method given as a String" do
      let(:opts) { {delegate: {to: "itself"}} }

      it "returns nil" do
        expect(preloads).to be_nil
      end
    end
  end

  context "when auto preload excludes a custom method" do
    let(:serializer_class) do
      Class.new(Serega) do
        config.auto_preload = {has_serializer_option: true}
        config.auto_preload_excluded_methods = %i[current_object]
      end
    end

    let(:opts) { {serializer: "AuthorSerializer"} }
    let(:method_name) { :current_object }

    it "returns nil" do
      expect(preloads).to be_nil
    end
  end
end
