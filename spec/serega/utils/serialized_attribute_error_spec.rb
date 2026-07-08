# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::SerializedAttributeError do
  let(:point) do
    double(name: :full_name, class: double(serializer_class: "UserSerializer"))
  end

  it "reraises the same error class with attribute and serializer details appended" do
    error = KeyError.new("key not found")

    expect { described_class.call(error, point) }
      .to raise_error(
        KeyError,
        "key not found\n(when serializing 'full_name' attribute in UserSerializer)"
      )
  end
end
