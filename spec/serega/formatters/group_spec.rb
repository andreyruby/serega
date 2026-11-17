# frozen_string_literal: true

RSpec.describe Serega::SeregaFormatters::Group do
  let(:group) { described_class.new(serializer_class) }
  let(:serializer_class) { Class.new(Serega) }

  before { allow(serializer_class).to receive(:formatter) }

  describe "#add" do
    subject(:add) { group.add(:money, value, allow_nil: true, &block) }

    let(:value) { [:fdiv, 100] }
    let(:block) { nil }

    it "defines the formatter in the serializer" do
      add

      expect(serializer_class).to have_received(:formatter).with(:money, [:fdiv, 100], allow_nil: true)
    end

    context "with a block" do
      let(:value) { nil }
      let(:block) { proc { |cents| cents / 100.0 } }

      it "passes the block to the formatter" do
        add

        expect(serializer_class).to have_received(:formatter).with(:money, nil, allow_nil: true) do |*, &formatter_block|
          expect(formatter_block).to equal block
        end
      end
    end
  end
end
