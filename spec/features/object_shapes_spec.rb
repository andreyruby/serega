# frozen_string_literal: true

RSpec.describe Serega do
  describe "serialization" do
    subject(:result) { user_serializer.new(**selection).to_h(user, context: context) }

    let(:user_serializer) do
      Class.new(Serega) do
        attribute :first_name
        attribute :last_name
      end
    end

    let(:context) { {} }
    let(:selection) { {} }

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

    context "with a Set after one object of the same serializer" do
      let(:user) { Set[double(first_name: "Lucy", last_name: "Wilde")] }

      before { user_serializer.to_h(double(first_name: "Felonious", last_name: "Gru")) }

      it "returns an Array" do
        expect(result).to eq([{first_name: "Lucy", last_name: "Wilde"}])
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

  describe "config.many" do
    subject(:result) { response_serializer.to_h(users, many: many) }

    let(:user_serializer) do
      Class.new(Serega) do
        attribute :first_name
      end
    end

    let(:response_serializer) do
      data_serializer = user_serializer
      Class.new(Serega) do
        config.many = false
        attribute :data, serializer: data_serializer, method: :itself, many: true
      end
    end

    let(:users) { [double(first_name: "Felonious"), double(first_name: "Lucy")] }
    let(:many) { nil }

    context "when config.many is false" do
      it "serializes a list as one object" do
        expect(result).to eq(data: [{first_name: "Felonious"}, {first_name: "Lucy"}])
      end

      it "serializes a list as one object to Struct objects" do
        expect(response_serializer.to_struct(users).data.map(&:first_name)).to eq %w[Felonious Lucy]
      end
    end

    context "when the call gives the :many option" do
      let(:many) { true }

      it "uses the option of the call" do
        expect(result).to eq [{data: [{first_name: "Felonious"}]}, {data: [{first_name: "Lucy"}]}]
      end
    end

    context "when a relation serializer sets config.many" do
      subject(:result) { team_serializer.to_h(team) }

      let(:team_serializer) do
        members_serializer = response_serializer
        Class.new(Serega) do
          attribute :members, serializer: members_serializer
        end
      end

      let(:team) { double(members: users) }

      it "serializes the relation as config.many says" do
        expect(result).to eq(members: {data: [{first_name: "Felonious"}, {first_name: "Lucy"}]})
      end
    end

    context "when config.many is true" do
      subject(:result) { user_serializer.to_h(user) }

      let(:user_serializer) do
        Class.new(Serega) do
          config.many = true
          attribute :first_name
        end
      end

      let(:user) { double(first_name: "Felonious") }

      it "serializes one object as a list" do
        expect(result).to eq [{first_name: "Felonious"}]
      end
    end
  end
end
