# frozen_string_literal: true

load_plugin_code :formatters

RSpec.describe Serega::SeregaPlugins::Formatters do
  describe "loading" do
    let(:serializer) { Class.new(Serega) }

    it "adds empty :formatters config option" do
      serializer.plugin :formatters
      expect(serializer.config.formatters.opts).to eq({})
    end

    it "adds allowed :format attribute option" do
      serializer.plugin :formatters
      expect(serializer.config.attribute_keys).to include(:format)
    end

    it "allows to provide formatters when loading plugin" do
      formatter = proc { |*args| }
      serializer.plugin :formatters, formatters: {foo: formatter}
      expect(serializer.config.formatters.opts).to eq({foo: formatter})
    end

    it "raises error if plugin defined with unknown option" do
      serializer = Class.new(Serega)
      expect { serializer.plugin(:formatters, foo: :bar) }
        .to raise_error Serega::SeregaError, <<~MESSAGE.strip
          Plugin :formatters does not accept the :foo option. Allowed options:
            - :formatters [Hash<Symbol, #call>] - Formatters (names and according callable values)
        MESSAGE
    end
  end

  describe "configuration" do
    let(:serializer) { Class.new(Serega) { plugin :formatters } }

    it "preserves formatters" do
      formatters1 = serializer.config.formatters
      formatters2 = serializer.config.formatters
      expect(formatters1).to be formatters2
    end

    it "allows to add formatters" do
      formatter = proc { |*args| }
      serializer.config.formatters.add({foo: formatter})
      expect(serializer.config.formatters.opts).to eq({foo: formatter})
    end
  end

  describe "validations" do
    let(:serializer) { Class.new(Serega) { plugin :formatters } }

    it "checks formatter when defined as config option is callable" do
      expect { serializer.config.formatters.add(foo: :bar) }.to raise_error Serega::SeregaError, "Option :foo must have callable value"
    end

    it "checks formatter params when defined as config option" do
      expect { serializer.config.formatters.add(foo: lambda { |obj| }) }.not_to raise_error
      expect { serializer.config.formatters.add(foo: lambda { |obj, ctx| }) }.not_to raise_error
      expect { serializer.config.formatters.add(foo: lambda { |obj, ctx:| }) }.not_to raise_error
      expect { serializer.config.formatters.add(foo: lambda {}) }
        .to raise_error Serega::SeregaError, <<~ERR.strip
          Invalid formatter parameters, valid parameters signatures:
          - (object)          # one positional parameter
          - (object, context) # two positional parameters
          - (object, :ctx)    # one positional parameter and :ctx keyword
        ERR
    end

    it "checks formatter is defined when adding attribute" do
      expect { serializer.attribute :foo, format: :some }
        .to raise_error Serega::SeregaError, "Formatter `:some` was not defined"
    end
  end

  describe "Attribute methods" do
    let(:serializer) { Class.new(Serega) { plugin :formatters } }
    let(:reverse) { ->(value) { value.reverse } }

    context "with configured formatter" do
      before do
        serializer.config.formatters.add(reverse: reverse)
      end

      it "formats result of attribute value" do
        attribute = serializer.attribute(:a, format: :reverse) { |obj| obj }

        expect(attribute.value("123", nil)).to eq "321"
        expect(attribute.value([1, 2, 3], nil)).to eq [3, 2, 1]
      end

      it "formats result of :const attribute value" do
        attribute = serializer.attribute(:a, const: "123", format: :reverse)

        expect(attribute.value(nil, nil)).to eq "321"
      end

      it "returns regular block when no format option specified" do
        attribute = serializer.attribute(:a) { |obj| obj }
        expect(attribute.value("123", nil)).to eq "123"
      end
    end

    context "with block formatter" do
      it "formats result of attribute value" do
        attribute = serializer.attribute(:a, format: reverse) { |obj| obj }

        expect(attribute.value("123", nil)).to eq "321"
        expect(attribute.value([1, 2, 3], nil)).to eq [3, 2, 1]
      end

      it "formats result of :const attribute value" do
        attribute = serializer.attribute(:a, const: "123", format: reverse)
        expect(attribute.value(nil, nil)).to eq "321"
      end
    end

    context "when formatter uses context" do
      let(:money) { ->(cents, ctx) { cents.to_f / 10**ctx[:money_digits] } }

      before do
        serializer.config.formatters.add(money: money)
      end

      it "formats result of attribute value" do
        attribute = serializer.attribute(:a, method: :itself, format: :money)

        expect(attribute.value(123, {money_digits: 2})).to eq 1.23
      end
    end

    context "when formatter uses ctx keyword" do
      let(:money) { ->(cents, ctx:) { cents.to_f / 10**ctx[:money_digits] } }

      before do
        serializer.config.formatters.add(money: money)
      end

      it "formats result of attribute value" do
        attribute = serializer.attribute(:a, method: :itself, format: :money)

        expect(attribute.value(123, {money_digits: 2})).to eq 1.23
      end
    end
  end
end
