# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::SerializedAttributeError do
  let(:error) { KeyError.new("key not found") }
  let(:point) { double(name: :full_name, attribute: attribute, class: double(serializer_class: "UserSerializer")) }
  let(:attribute) { double(name: :full_name, location: location, class: double(serializer_class: "UserSerializer")) }
  let(:location) { "app/serializers/user_serializer.rb:3" }

  describe ".call" do
    subject(:reraise) { described_class.call(error, point) }

    it "reraises the same error class with the attribute, the serializer and the attribute location" do
      expect { reraise }
        .to raise_error(KeyError, "key not found\n(when serializing the 'full_name' attribute in UserSerializer, app/serializers/user_serializer.rb:3)")
    end

    context "when the attribute location is unknown" do
      let(:location) { nil }

      it "reraises the error with the attribute and the serializer" do
        expect { reraise }
          .to raise_error(KeyError, "key not found\n(when serializing the 'full_name' attribute in UserSerializer)")
      end
    end

    context "with an error raised outside the generated code" do
      let(:error) do
        raise KeyError, "key not found"
      rescue KeyError => error
        error
      end

      it "keeps the backtrace" do
        backtrace = error.backtrace

        expect { reraise }.to raise_error(KeyError) { |reraised| expect(reraised.backtrace).to eq backtrace }
      end
    end

    context "with an error with the backtrace of another call stack" do
      let(:error) { KeyError.new("key not found").tap { |error| error.set_backtrace(["app/models/user.rb:5"]) } }

      it "keeps the backtrace" do
        expect { reraise }.to raise_error(KeyError) { |reraised| expect(reraised.backtrace).to eq ["app/models/user.rb:5"] }
      end
    end
  end

  describe ".condition" do
    subject(:reraise) { described_class.condition(error, attribute, :unless) }

    it "reraises the same error class with the condition, the attribute, the serializer and the attribute location" do
      expect { reraise }
        .to raise_error(KeyError, "key not found\n(when checking the :unless condition of the 'full_name' attribute in UserSerializer, app/serializers/user_serializer.rb:3)")
    end

    context "when the attribute location is unknown" do
      let(:location) { nil }

      it "reraises the error with the condition, the attribute and the serializer" do
        expect { reraise }
          .to raise_error(KeyError, "key not found\n(when checking the :unless condition of the 'full_name' attribute in UserSerializer)")
      end
    end
  end
end
