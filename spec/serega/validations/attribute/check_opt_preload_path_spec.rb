# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptPreloadPath do
  let(:validator) { described_class }

  it "does not raise error when no preload_path option" do
    expect { validator.call({}) }.not_to raise_error
  end

  it "raises error when :preload_path option provided without :preload option" do
    expect { validator.call({preload_path: :foo}) }
      .to raise_error Serega::SeregaError, "Invalid option preload_path: :foo. Can be provided only when :preload option provided"
  end

  it "raises error when :preload_path option provided without :serializer option" do
    expect { validator.call({preload_path: :foo, preload: :foo}) }
      .to raise_error Serega::SeregaError, "Invalid option preload_path: :foo. Can be provided only when :serializer option provided"
  end

  it "raises error when :preload_path option is not included in :preload option" do
    expect { validator.call({preload_path: :foo, preload: {bar: :bazz}, serializer: :foo}) }
      .to raise_error Serega::SeregaError, "Invalid preload_path (:foo). Can be one of [:bar], [:bar, :bazz]"
  end

  it "does not raise error when provided :preload_path is nil" do
    expect { validator.call({preload_path: nil, preload: :bar, serializer: :foo}) }
      .not_to raise_error
  end

  it "does not raise error when provided :preload_path is nil with multiple allowed paths" do
    expect { validator.call({preload_path: nil, preload: {bar: :bazz}, serializer: :foo}) }
      .not_to raise_error
  end

  it "raises error when :preload_path option must be provided" do
    expect { validator.call({preload: {bar: :bazz}, serializer: :foo}) }
      .to raise_error Serega::SeregaError, "Option :preload_path must be provided. Possible values: [:bar], [:bar, :bazz]"
  end

  it "does not raises error with valid :preload_path" do
    expect { validator.call({preload_path: :foo, preload: :foo, serializer: :foo}) }.not_to raise_error
    expect { validator.call({preload_path: :foo, preload: %i[foo bar], serializer: :foo}) }.not_to raise_error
    expect { validator.call({preload_path: :bar, preload: %i[foo bar], serializer: :foo}) }.not_to raise_error
  end

  it "does not raises error with multiple :preload_paths" do
    expect { validator.call({preload_path: [[:foo], [:bar]], preload: %i[foo bar], serializer: :foo}) }
      .not_to raise_error
  end

  it "raises error when one of multiple :preload_paths in invalid" do
    expect { validator.call({preload_path: [[:foo], [:BAR]], preload: %i[foo bar], serializer: :foo}) }
      .to raise_error Serega::SeregaError, "Invalid preload_path ([:BAR]). Can be one of [:foo], [:bar]"
  end
end
