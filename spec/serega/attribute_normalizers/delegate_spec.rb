# frozen_string_literal: true

RSpec.describe Serega::AttributeNormalizers::Delegate do
  subject(:resolver) { described_class.call(delegate, :name, serializer_class.config) }

  let(:serializer_class) { Class.new(Serega) }
  let(:delegate) { {to: :profile} }

  it "calls the attribute method of the delegated object" do
    expect(resolver.call(double(profile: double(name: "Kate")))).to eq "Kate"
    expect { resolver.call(double(profile: nil)) }.to raise_error NoMethodError
  end

  context "with the :method option" do
    let(:delegate) { {to: :profile, method: :title} }

    it "calls the given method of the delegated object" do
      expect(resolver.call(double(profile: double(title: "Kate")))).to eq "Kate"
    end
  end

  context "with allow_nil: true" do
    let(:delegate) { {to: :profile, allow_nil: true} }

    it "returns nil when the delegated object is nil" do
      expect(resolver.call(double(profile: nil))).to be_nil
      expect(resolver.call(double(profile: double(name: "Kate")))).to eq "Kate"
    end
  end

  context "when the config allows nil by default" do
    let(:serializer_class) { Class.new(Serega) { config.delegate_default_allow_nil = true } }

    it "returns nil when the delegated object is nil" do
      expect(resolver.call(double(profile: nil))).to be_nil
    end
  end

  context "with :to_hash_access" do
    let(:delegate) { {to: :profile, to_hash_access: true} }

    it "reads the delegated object by key, then calls the method" do
      expect(resolver.call({profile: double(name: "Kate")})).to eq "Kate"
    end
  end

  context "with :hash_access" do
    let(:delegate) { {to: :profile, hash_access: true, allow_nil: true} }

    it "calls the method, then reads the value by key" do
      expect(resolver.call(double(profile: {name: "Kate"}))).to eq "Kate"
      expect(resolver.call(double(profile: nil))).to be_nil
    end
  end
end
