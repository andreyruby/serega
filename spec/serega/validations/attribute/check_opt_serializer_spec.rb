# frozen_string_literal: true

RSpec.describe Serega::SeregaValidations::Attribute::CheckOptSerializer do
  def error(value)
    "Invalid option :serializer => #{value.inspect}. Can be a Serega subclass, a String or a Proc without arguments"
  end

  it "allows Serega subclass" do
    serega = Serega
    expect { described_class.call(serializer: serega) }.to raise_error error(serega)

    subclass = Class.new(serega)
    expect { described_class.call(serializer: subclass) }.not_to raise_error

    subsubclass = Class.new(subclass)
    expect { described_class.call(serializer: subsubclass) }.not_to raise_error
  end

  it "allows procs without arguments" do
    block = proc {}
    expect { described_class.call(serializer: block) }.not_to raise_error
  end

  it "prohibits procs with arguments" do
    block_with_params = proc { |_param| Class.new(Serega) }
    expect { described_class.call(serializer: block_with_params) }.to raise_error error(block_with_params)
  end

  it "allows strings" do
    expect { described_class.call(serializer: "Foo") }.not_to raise_error
  end

  it "prohibits non Serega-subclasses" do
    expect { described_class.call(serializer: nil) }.to raise_error error(nil)
    expect { described_class.call(serializer: false) }.to raise_error error(false)
    expect { described_class.call(serializer: true) }.to raise_error error(true)
    expect { described_class.call(serializer: Object) }.to raise_error error(Object)
  end
end
