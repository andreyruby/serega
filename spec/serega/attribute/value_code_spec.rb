# frozen_string_literal: true

RSpec.describe Serega::SeregaAttribute::ValueCode do
  let(:serializer_class) { Class.new(Serega) }

  describe "#plain" do
    subject(:code) { Serega::SeregaAttribute.new(serializer_class, name: :name, opts: opts).value_code.plain(constants_prefix) }

    let(:opts) { {} }
    let(:constants_prefix) { "" }

    it "returns the code of the value reader" do
      expect(code).to eq "source.name"
    end

    context "with the :delegate option" do
      let(:opts) { {delegate: {to: :profile}} }

      it "returns the code of the delegate reader" do
        expect(code).to eq "source.profile.name"
      end
    end

    context "with the :default option" do
      let(:opts) { {default: "Ann"} }

      it "returns the code that reads the value or the default" do
        expect(code).to eq "(value = source.name).nil? ? DEFAULTS[:name] : value"
      end
    end

    context "with the :const option" do
      let(:opts) { {const: "Ann"} }

      it "returns the code that reads the constant" do
        expect(code).to eq "CONSTANTS[:name]"
      end
    end

    context "with the :value option" do
      let(:opts) { {value: proc { |user| user.name }} }

      it "returns nil" do
        expect(code).to be_nil
      end
    end

    context "with the :format option" do
      let(:opts) { {format: proc { |name| name.upcase }} }

      it "returns the code that formats the value" do
        expect(code).to eq "FORMATTERS[:name].call(source.name)"
      end
    end

    context "with the :format and :default options" do
      let(:opts) { {format: proc { |name| name.upcase }, default: "Ann"} }

      it "returns the code that formats the value or the default" do
        expect(code).to eq "FORMATTERS[:name].call((value = source.name).nil? ? DEFAULTS[:name] : value)"
      end
    end

    context "with a constants prefix" do
      let(:opts) { {format: proc { |name| name.upcase }, default: "Ann"} }
      let(:constants_prefix) { "SeregaAttributeValues::" }

      it "returns the code that reads the constants with the prefix" do
        expect(code).to eq "SeregaAttributeValues::FORMATTERS[:name].call((value = source.name).nil? ? SeregaAttributeValues::DEFAULTS[:name] : value)"
      end
    end

    context "with a :format option that reads the context" do
      let(:opts) { {format: proc { |name, ctx| "#{ctx[:title]} #{name}" }} }

      it "returns nil" do
        expect(code).to be_nil
      end
    end
  end

  describe "#plain?" do
    subject(:plain) { Serega::SeregaAttribute.new(serializer_class, name: :name, opts: opts).value_code.plain? }

    let(:opts) { {} }

    it "returns true" do
      expect(plain).to be true
    end

    context "with the :value option" do
      let(:opts) { {value: proc { |user| user.name }} }

      it "returns false" do
        expect(plain).to be false
      end
    end
  end

  describe "#plain_method" do
    subject(:code) { Serega::SeregaAttribute.new(serializer_class, name: :name, opts: {default: "Ann"}).value_code.plain_method(:read_name) }

    it "returns the method that reads the value" do
      expect(code).to eq "def read_name(source) = (value = source.name).nil? ? DEFAULTS[:name] : value"
    end
  end

  describe "#callable" do
    subject(:code) { Serega::SeregaAttribute.new(serializer_class, name: :name, opts: opts).value_code.callable("callable", "batches", "") }

    let(:opts) { {value: value} }
    let(:value) { proc { |user| user.name } }

    it "returns the code that calls the callable with the source" do
      expect(code).to eq "callable.call(source)"
    end

    context "with the :default and :format options" do
      let(:opts) { {value: value, default: "Ann", format: proc { |name| name.upcase }} }

      it "returns the code that formats the value or the default" do
        expect(code).to eq "FORMATTERS[:name].call((value = callable.call(source)).nil? ? DEFAULTS[:name] : value)"
      end
    end

    context "with a :format option that reads the context" do
      let(:opts) { {value: value, format: proc { |name, ctx| "#{ctx[:title]} #{name}" }} }

      it "returns nil" do
        expect(code).to be_nil
      end
    end

    context "without the :value option" do
      let(:opts) { {} }

      it "returns nil" do
        expect(code).to be_nil
      end
    end
  end

  describe "#batch" do
    subject(:code) { Serega::SeregaAttribute.new(serializer_class, name: :name, opts: opts).value_code.batch("batch", "") }

    let(:opts) { {batch: proc { |users| users }} }

    it "returns the code that reads the value from the loaded batch" do
      expect(code).to eq "batch[source.id]"
    end

    context "with the :default and :format options" do
      let(:opts) { {batch: proc { |users| users }, default: "Ann", format: proc { |name| name.upcase }} }

      it "returns the code that formats the value or the default" do
        expect(code).to eq "FORMATTERS[:name].call((value = batch[source.id]).nil? ? DEFAULTS[:name] : value)"
      end
    end

    context "with the :value option" do
      let(:opts) { {batch: proc { |users| users }, value: proc { |user, batches:| batches[:name][user.id] }} }

      it "returns nil" do
        expect(code).to be_nil
      end
    end
  end
end
