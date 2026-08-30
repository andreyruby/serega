# frozen_string_literal: true

RSpec.describe Serega do
  describe "serialization" do
    subject(:result) { user_serializer.new(**modifiers).to_h(user, context: context) }

    let(:user_serializer) do
      Class.new(Serega) do
        attribute :first_name
        attribute :last_name
      end
    end
    let(:context) { {} }
    let(:modifiers) { {} }

    context "with empty array" do
      let(:user) { [] }

      it "returns empty array" do
        expect(result).to eq([])
      end
    end

    context "with object with attributes" do
      let(:user) { double(first_name: "FIRST_NAME", last_name: "LAST_NAME") }

      it "returns hash" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end
    end

    context "with Struct object" do
      let(:user_struct) { Struct.new(:first_name, :last_name) }
      let(:user) { user_struct.new("FIRST_NAME", "LAST_NAME") }

      it "serializes Struct as a single object, not as a collection" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end

      it "wraps Struct in an array when :many option is true" do
        expect(user_serializer.to_h(user, many: true))
          .to eq([{first_name: "FIRST_NAME", last_name: "LAST_NAME"}])
      end
    end

    context "with Hash object" do
      let(:user_serializer) do
        Class.new(Serega) do
          attribute :first_name, value: proc { |user| user[:first_name] }
          attribute :last_name, value: proc { |user| user[:last_name] }
        end
      end
      let(:user) { {first_name: "FIRST_NAME", last_name: "LAST_NAME"} }

      it "serializes Hash as a single object, not as a collection of key-value pairs" do
        expect(result).to eq({first_name: "FIRST_NAME", last_name: "LAST_NAME"})
      end
    end
  end
end
