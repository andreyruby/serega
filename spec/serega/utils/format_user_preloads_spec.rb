# frozen_string_literal: true

RSpec.describe Serega::SeregaUtils::FormatUserPreloads do
  let(:format) { described_class }

  it "transforms nil to empty hash" do
    preloads = nil
    expect(format.call(preloads)).to eq({})
  end

  it "transforms false to empty hash" do
    preloads = false
    expect(format.call(preloads)).to eq({})
  end

  it "transforms Symbol" do
    preloads = :foo
    expect(format.call(preloads)).to eq({foo: {}})
  end

  it "transforms String" do
    preloads = "foo"
    expect(format.call(preloads)).to eq({foo: {}})
  end

  it "transforms Hash" do
    preloads = {foo: :bar}
    expect(format.call(preloads)).to eq({foo: {bar: {}}})
  end

  it "transforms Array" do
    preloads = %i[foo bar]
    expect(format.call(preloads)).to eq({foo: {}, bar: {}})
  end

  it "transforms nested hashes and arrays" do
    preloads = [:foo, {"bar" => "bazz"}, ["bazz"]]
    expect(format.call(preloads)).to eq({foo: {}, bar: {bazz: {}}, bazz: {}})

    preloads = {"bar" => "bazz", :foo => [:bar, "bazz"]}
    expect(format.call(preloads)).to eq({bar: {bazz: {}}, foo: {bar: {}, bazz: {}}})
  end

  it "raises error when invalid data added" do
    val = 123
    expect { format.call(val) }
      .to raise_error Serega::SeregaError,
        "Preload option value can consist from Symbols, Arrays, Hashes (#{val.class} #{val.inspect} was provided)"
  end
end
