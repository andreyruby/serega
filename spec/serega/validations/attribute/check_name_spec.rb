# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckName do
  def error(name)
    %(Invalid attribute name = #{name.inspect}. Allowed characters: "a-z", "A-Z", "0-9", "_", "-", "~")
  end

  it "shows a Symbol name as a String in the error" do
    expect { described_class.call(:"foo bar") }.to raise_error Serega::SeregaError, error("foo bar")
  end

  it "prohibits empty name" do
    name = ""
    expect { described_class.call(name) }.to raise_error Serega::SeregaError, error(name)
  end

  it "allows one char _A-Za-z0-9~-" do
    expect { described_class.call("a") }.not_to raise_error
    expect { described_class.call("s") }.not_to raise_error
    expect { described_class.call("z") }.not_to raise_error
    expect { described_class.call("A") }.not_to raise_error
    expect { described_class.call("S") }.not_to raise_error
    expect { described_class.call("Z") }.not_to raise_error
    expect { described_class.call("0") }.not_to raise_error
    expect { described_class.call("5") }.not_to raise_error
    expect { described_class.call("9") }.not_to raise_error
    expect { described_class.call("_") }.not_to raise_error
    expect { described_class.call("~") }.not_to raise_error
    expect { described_class.call("-") }.not_to raise_error

    expect { described_class.call("+") }.to raise_error Serega::SeregaError, error("+")
    expect { described_class.call(" ") }.to raise_error Serega::SeregaError, error(" ")
    expect { described_class.call("!") }.to raise_error Serega::SeregaError, error("!")
    expect { described_class.call("(") }.to raise_error Serega::SeregaError, error("(")
    expect { described_class.call(")") }.to raise_error Serega::SeregaError, error(")")
    expect { described_class.call("[") }.to raise_error Serega::SeregaError, error("[")
    expect { described_class.call("]") }.to raise_error Serega::SeregaError, error("]")
  end

  it "allows two chars _A-Za-z0-9~-" do
    expect { described_class.call("aZ") }.not_to raise_error
    expect { described_class.call("Za") }.not_to raise_error
    expect { described_class.call("09") }.not_to raise_error
    expect { described_class.call("_a") }.not_to raise_error
    expect { described_class.call("a_") }.not_to raise_error
    expect { described_class.call("__") }.not_to raise_error
    expect { described_class.call("a~") }.not_to raise_error
    expect { described_class.call("a-") }.not_to raise_error
    expect { described_class.call("-a") }.not_to raise_error
    expect { described_class.call("a+") }.to raise_error Serega::SeregaError, error("a+")
    expect { described_class.call("+a") }.to raise_error Serega::SeregaError, error("+a")
    expect { described_class.call("!!") }.to raise_error Serega::SeregaError, error("!!")
  end

  it "allows multiple chars _A-Za-z0-9~-" do
    expect { described_class.call("foo") }.not_to raise_error
    expect { described_class.call("bar") }.not_to raise_error
    expect { described_class.call("fooBAR123") }.not_to raise_error
    expect { described_class.call("foo-123") }.not_to raise_error
    expect { described_class.call("foo_3") }.not_to raise_error
    expect { described_class.call("_-_") }.not_to raise_error
    expect { described_class.call("---") }.not_to raise_error
    expect { described_class.call("~~~") }.not_to raise_error

    expect { described_class.call("foo!") }.to raise_error Serega::SeregaError, error("foo!")
    expect { described_class.call("!foo") }.to raise_error Serega::SeregaError, error("!foo")
    expect { described_class.call("foo+bar") }.to raise_error Serega::SeregaError, error("foo+bar")
  end
end
