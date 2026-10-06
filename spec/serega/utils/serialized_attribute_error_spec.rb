# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::SerializedAttributeError do
  subject(:reraise) { described_class.call(error, point) }

  let(:error) { KeyError.new("key not found") }
  let(:point) { double(name: :full_name, attribute: attribute, class: double(serializer_class: "UserSerializer")) }
  let(:attribute) { double(location: "app/serializers/user_serializer.rb:3") }

  it "reraises the same error class with the attribute, the serializer and the attribute location" do
    expect { reraise }
      .to raise_error(KeyError, "key not found\n(when serializing 'full_name' attribute in UserSerializer, app/serializers/user_serializer.rb:3)")
  end

  context "when the attribute location is unknown" do
    let(:attribute) { double(location: nil) }

    it "reraises the error with the attribute and the serializer" do
      expect { reraise }
        .to raise_error(KeyError, "key not found\n(when serializing 'full_name' attribute in UserSerializer)")
    end
  end
end
