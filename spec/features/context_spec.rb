# frozen_string_literal: true

RSpec.describe Serega do
  describe "serialization context" do
    subject(:result) { user_serializer.to_h(user, opts) }

    let(:user_serializer) do
      Class.new(described_class) do
        attribute :context, value: proc { |_user, ctx| ctx }
      end
    end

    let(:user) { Struct.new(:id).new(1) }

    context "without a context" do
      let(:opts) { nil }

      it "passes a frozen empty Hash" do
        expect(result[:context]).to be_frozen.and eq({})
      end
    end
  end
end
