# frozen_string_literal: true

RSpec.describe Serega::AttributeValueResolvers do
  describe described_class::DelegateResolver do
    let(:delegate_to) { :profile }
    let(:method_name) { :name }

    describe ".get" do
      context "when allow_nil is true" do
        it "creates DelegateAllowNil resolver" do
          resolver = described_class.get(delegate_to, method_name, true)
          expect(resolver).to be_a(Serega::AttributeValueResolvers::DelegateAllowNil)
        end
      end

      context "when allow_nil is false" do
        it "creates Delegate resolver" do
          resolver = described_class.get(delegate_to, method_name, false)
          expect(resolver).to be_a(Serega::AttributeValueResolvers::Delegate)
        end
      end
    end
  end

  describe described_class::DelegateAllowNil do
    let(:delegate_to) { :profile }
    let(:method_name) { :name }

    describe "#initialize" do
      subject(:resolver) { described_class.new(delegate_to, method_name) }

      it "sets delegate_to and method_name" do
        profile = double(name: "John")
        object = double(profile: profile)
        expect(resolver.call(object)).to eq("John")
      end
    end

    describe "#call" do
      let(:resolver) { described_class.new(delegate_to, method_name) }

      context "when delegated object exists" do
        let(:profile) { double(name: "John") }
        let(:object) { double(profile: profile) }

        it "calls method on delegated object" do
          expect(resolver.call(object)).to eq("John")
        end
      end

      context "when delegated object is nil" do
        let(:object) { double(profile: nil) }

        it "returns nil without raising error" do
          expect(resolver.call(object)).to be_nil
        end
      end
    end
  end

  describe described_class::Delegate do
    let(:delegate_to) { :profile }
    let(:method_name) { :name }

    describe "#initialize" do
      subject(:resolver) { described_class.new(delegate_to, method_name) }

      it "sets delegate_to and method_name" do
        profile = double(name: "John")
        object = double(profile: profile)
        expect(resolver.call(object)).to eq("John")
      end
    end

    describe "#call" do
      let(:resolver) { described_class.new(delegate_to, method_name) }

      context "when delegated object exists" do
        let(:profile) { double(name: "John") }
        let(:object) { double(profile: profile) }

        it "calls method on delegated object" do
          expect(resolver.call(object)).to eq("John")
        end
      end

      context "when delegated object is nil" do
        let(:object) { double(profile: nil) }

        it "raises NoMethodError" do
          expect { resolver.call(object) }.to raise_error(NoMethodError)
        end
      end
    end
  end
end
