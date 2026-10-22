# frozen_string_literal: true

RSpec.describe Serega::AttributeNormalizers::HashAccess do
  subject(:resolver) { described_class.call(option, :name, defaults) }

  let(:option) { true }
  let(:defaults) { Serega::SeregaConfig::HashAccessConfig.new(default_mode: :string, default_allow_missing_key: true) }

  it "reads the key with the default mode and the default allow_missing_key" do
    expect(resolver.call({"name" => "Kate"})).to eq "Kate"
    expect(resolver.call({})).to be_nil
  end

  context "without the option" do
    let(:option) { nil }

    it "calls the method" do
      expect(resolver.call(double(name: "Kate"))).to eq "Kate"
    end
  end

  context "with a mode" do
    let(:option) { :symbol }

    it "reads the key with the mode and the default allow_missing_key" do
      expect(resolver.call({name: "Kate"})).to eq "Kate"
      expect(resolver.call({})).to be_nil
    end
  end

  context "with a Hash with :mode and :allow_missing_key" do
    let(:option) { {mode: :symbol, allow_missing_key: false} }

    it "reads the key with the given mode and allow_missing_key" do
      expect(resolver.call({name: "Kate"})).to eq "Kate"
      expect { resolver.call({}) }.to raise_error KeyError
    end
  end

  context "with an empty Hash" do
    let(:option) { {} }

    it "reads the key with the default mode and the default allow_missing_key" do
      expect(resolver.call({"name" => "Kate"})).to eq "Kate"
      expect(resolver.call({})).to be_nil
    end
  end
end
