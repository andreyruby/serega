# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Initiate::CheckPresetModifiers do
  subject(:check) { described_class.new.call(lazy_serializer, only, {}, {}) }

  let(:lazy_serializer) do
    nested = Class.new(Serega) { attribute :name }

    Class.new(Serega) do
      attribute :loaded, serializer: nested
      attribute :lazy, serializer: -> { nested }
      attribute :named, serializer: "CheckPresetModifiersSpecSerializer"
      attribute :plain
    end
  end

  let(:only) { {lazy: {extra: {}}} }

  it "skips the nested fields of a relation with a Proc serializer" do
    expect { check }.not_to raise_error
  end

  context "with nested fields of a relation with a serializer name" do
    let(:only) { {named: {extra: {}}} }

    it "skips the nested fields" do
      expect { check }.not_to raise_error
    end
  end

  context "with nested fields of a loaded serializer" do
    let(:only) { {loaded: {extra: {}}} }

    it "raises an AttributeNotExist error" do
      expect { check }.to raise_error Serega::AttributeNotExist, "Not existing attributes: loaded(extra)"
    end
  end

  context "with nested fields of an attribute without a serializer" do
    let(:only) { {plain: {extra: {}}} }

    it "raises an AttributeNotExist error" do
      expect { check }.to raise_error Serega::AttributeNotExist, "Not existing attributes: plain(extra)"
    end
  end
end
