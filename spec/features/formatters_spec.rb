# frozen_string_literal: true

RSpec.describe Serega do
  describe "formatters" do
    subject(:result) { user_serializer.to_h(user, context: context) }

    let(:user_class) { Struct.new(:balance, :score) }
    let(:user) { user_class.new(1234, 0.5) }
    let(:context) { {currency: "EUR"} }

    context "with a defined formatter" do
      let(:user_serializer) do
        Class.new(Serega) do
          formatter :money, ->(cents) { cents / 100.0 }
          attribute :balance, format: :money
        end
      end

      it "formats the value" do
        expect(result).to eq(balance: 12.34)
      end
    end

    context "with a formatter defined in the parent serializer" do
      let(:base_serializer) do
        Class.new(Serega) do
          formatter :money, ->(cents) { cents / 100.0 }
        end
      end

      let(:user_serializer) do
        Class.new(base_serializer) do
          attribute :balance, format: :money
        end
      end

      it "formats the value" do
        expect(result).to eq(balance: 12.34)
      end
    end

    context "with a callable :format option" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :score, format: proc { |score| "#{(score * 100).round}%" }
        end
      end

      it "formats the value" do
        expect(result).to eq(score: "50%")
      end
    end

    context "with a formatter that reads the context" do
      let(:user_serializer) do
        Class.new(Serega) do
          formatter :money, ->(cents, ctx:) { "#{cents / 100.0} #{ctx[:currency]}" }
          attribute :balance, format: :money
        end
      end

      it "passes the serialization context to the formatter" do
        expect(result).to eq(balance: "12.34 EUR")
      end
    end

    context "with a :default option" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :balance, default: 0, format: proc { |cents| cents / 100.0 }
        end
      end

      let(:user) { user_class.new(nil, 0.5) }

      it "formats the default value" do
        expect(result).to eq(balance: 0.0)
      end
    end
  end

  describe ".formatter" do
    let(:user_serializer) { Class.new(described_class) }
    let(:money) { ->(cents) { cents / 100.0 } }

    it "defines a formatter" do
      user_serializer.formatter(:money, money)

      expect(user_serializer.formatters[:money].call(1234, nil)).to eq 12.34
    end

    it "defines a formatter with a block" do
      user_serializer.formatter(:money) { |cents| cents / 100.0 }

      expect(user_serializer.formatters[:money].call(1234, nil)).to eq 12.34
    end

    it "raises an error without a formatter" do
      expect { user_serializer.formatter(:money) }
        .to raise_error Serega::SeregaError, "Formatter must be defined with a callable value or block"
    end

    it "raises an error with a value and a block" do
      expect { user_serializer.formatter(:money, money) { |cents| cents } }
        .to raise_error Serega::SeregaError, "Formatter must be defined with a callable value or block"
    end

    it "raises an error for a name that is not a Symbol" do
      expect { user_serializer.formatter("money", money) }
        .to raise_error Serega::SeregaError, "Formatter name must be a Symbol"
    end

    it "raises an error for an invalid formatter" do
      expect { user_serializer.formatter(:money, "round") }
        .to raise_error Serega::SeregaError, "Option :money must have callable value"
    end

    context "with a child serializer" do
      let(:child_serializer) { Class.new(user_serializer) }

      it "defines the formatter in the child serializer only" do
        child_serializer.formatter(:money, money)

        expect(child_serializer.formatters.keys).to eq [:money]
        expect(user_serializer.formatters).to eq({})
      end
    end

    context "when the serializer is locked" do
      before { user_serializer.to_h(nil) }

      it "raises an error" do
        expect { user_serializer.formatter(:money, money) }
          .to raise_error Serega::SeregaError, "#{user_serializer} can not be changed after it was used for serialization"
      end
    end
  end
end
