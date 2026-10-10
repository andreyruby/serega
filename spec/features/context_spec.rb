# frozen_string_literal: true

RSpec.describe Serega do
  describe "serialization context" do
    subject(:result) { user_serializer.to_h(user, opts) }

    let(:user_serializer) do
      Class.new(described_class) do
        attribute :context, value: proc { |_user, ctx| ctx }
        freeze
      end
    end

    let(:user) { Struct.new(:id).new(1) }

    context "without a context" do
      let(:opts) { nil }

      it "passes a frozen empty Hash" do
        expect(result[:context]).to be_frozen.and eq({})
      end
    end

    context "with a context" do
      let(:opts) { {context: context} }
      let(:context) { {"current_user_id" => 1, :show_emails => true} }

      it "passes the given context" do
        expect(result[:context]).to equal context
      end

      it "does not change the given context" do
        result

        expect(context).to eq("current_user_id" => 1, :show_emails => true)
        expect(context).not_to be_frozen
      end
    end

    context "with String option names" do
      let(:opts) { {"context" => context} }
      let(:context) { {current_user_id: 1} }

      it "does not change the given options" do
        result

        expect(opts).to eq("context" => context)
      end
    end
  end

  describe ".new" do
    subject(:serializer) { user_serializer.new(modifiers) }

    let(:user_serializer) do
      Class.new(described_class) do
        attribute :first_name
        attribute :email
        freeze
      end
    end

    let(:modifiers) { {"only" => [:first_name]} }

    it "does not change the given modifiers" do
      serializer

      expect(modifiers).to eq("only" => [:first_name])
    end
  end
end
