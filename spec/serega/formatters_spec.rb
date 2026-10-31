# frozen_string_literal: true

RSpec.describe Serega::SeregaFormatters do
  describe ".build" do
    subject(:formatter) { described_class.build(declaration) }

    context "with a callable" do
      let(:declaration) { ->(cents) { cents / 100.0 } }

      it "returns a callable formatter" do
        expect(formatter).to be_a(Serega::SeregaFormatters::Callable)
      end
    end

    context "with a method name" do
      let(:declaration) { :to_s }

      it "returns a method formatter" do
        expect(formatter).to be_a(Serega::SeregaFormatters::Method)
      end
    end

    context "with a Hash with a callable and allow_nil: true" do
      let(:declaration) { {use: ->(cents) { cents.inspect }, allow_nil: true} }

      it "returns a callable formatter that keeps nil" do
        expect(formatter.call(nil, {})).to be_nil
      end
    end

    context "with a Hash with a method name and allow_nil: true" do
      let(:declaration) { {use: :inspect, allow_nil: true} }

      it "returns a method formatter that keeps nil" do
        expect(formatter.call(nil, {})).to be_nil
      end
    end
  end
end
