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

    context "with a method name formatter" do
      let(:user_serializer) do
        Class.new(Serega) do
          formatter :string, :to_s
          attribute :balance, format: :string
        end
      end

      it "calls the method on the value" do
        expect(result).to eq(balance: "1234")
      end
    end

    context "with a method name and arguments formatter" do
      let(:user_serializer) do
        Class.new(Serega) do
          formatter :money, [:fdiv, 100]
          attribute :balance, format: :money
        end
      end

      it "calls the method with the arguments" do
        expect(result).to eq(balance: 12.34)
      end
    end

    context "with a method formatter with an object argument" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :balance, format: [:fdiv, Rational(100)]
          attribute :score, format: {use: [:*, Rational(100)], allow_nil: true}
        end
      end

      it "calls the method with the argument" do
        expect(result).to eq(balance: 12.34, score: 50.0)
      end
    end

    context "with an operator method formatter" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :score, format: [:*, 100]
        end
      end

      it "calls the method with the arguments" do
        expect(result).to eq(score: 50.0)
      end
    end

    context "with allow_nil: true" do
      let(:user_serializer) do
        Class.new(Serega) do
          formatter :money, [:fdiv, 100], allow_nil: true
          attribute :balance, format: :money
          attribute :score, format: {use: ->(score) { "#{(score * 100).round}%" }, allow_nil: true}
        end
      end

      let(:user) { user_class.new(nil, nil) }

      it "keeps nil values" do
        expect(result).to eq(balance: nil, score: nil)
      end
    end

    context "with allow_nil: true and a formatter that reads the context" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :balance, format: {use: ->(cents, ctx) { "#{cents / 100.0} #{ctx[:currency]}" }, allow_nil: true}
        end
      end

      let(:user) { user_class.new(nil, 0.5) }

      it "keeps the nil value" do
        expect(result).to eq(balance: nil)
      end
    end

    context "without allow_nil" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :balance, format: [:fdiv, 100]
        end
      end

      let(:user) { user_class.new(nil, 0.5) }

      it "raises the error of the method called on nil" do
        expect { result }.to raise_error NoMethodError, /fdiv/
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
        .to raise_error Serega::SeregaError, "Formatter must be defined with a value or a block"
    end

    it "raises an error with a value and a block" do
      expect { user_serializer.formatter(:money, money) { |cents| cents } }
        .to raise_error Serega::SeregaError, "Formatter must be defined with a value or a block"
    end

    it "raises an error for a name that is not a Symbol" do
      expect { user_serializer.formatter("money", money) }
        .to raise_error Serega::SeregaError, "Formatter name must be a Symbol"
    end

    it "raises an error for an invalid formatter" do
      expect { user_serializer.formatter(:money, "round") }
        .to raise_error Serega::SeregaError, /Invalid formatter :money/
    end

    it "defines a formatter with a method name and arguments" do
      user_serializer.formatter(:money, [:fdiv, 100])

      expect(user_serializer.formatters[:money].call(1234, nil)).to eq 12.34
    end

    it "defines a formatter that keeps nil values" do
      user_serializer.formatter(:money, [:fdiv, 100], allow_nil: true)

      expect(user_serializer.formatters[:money].call(nil, nil)).to be_nil
    end

    it "raises an error for a not boolean :allow_nil" do
      expect { user_serializer.formatter(:money, money, allow_nil: 1) }
        .to raise_error Serega::SeregaError, "Invalid option :allow_nil => 1. Must have a boolean value"
    end

    it "raises an error for a Hash formatter" do
      expect { user_serializer.formatter(:money, {use: money}) }
        .to raise_error Serega::SeregaError, /Invalid formatter :money/
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
