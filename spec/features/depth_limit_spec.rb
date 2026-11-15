# frozen_string_literal: true

RSpec.describe Serega do
  describe "Relation cycles" do
    subject(:result) { user_serializer.to_h(user, with: with) }

    let(:user) { {name: "Ann", friends: [{name: "Bob", friends: []}]} }
    let(:with) { {friends: :friends} }
    let(:hide) { true }

    let(:user_serializer) do
      hide_friends = hide
      Class.new(described_class) do
        attribute :name, value: proc { |user| user[:name] }
        attribute :friends, serializer: -> { self }, value: proc { |user| user[:friends] }, hide: hide_friends
      end
    end

    context "when the call selects the relation at each level" do
      let(:with) { {friends: :friends} }

      it "serializes the selected levels" do
        expect(result).to eq(name: "Ann", friends: [{name: "Bob", friends: []}])
      end
    end

    context "when the relation is shown by default" do
      let(:hide) { false }

      it "raises DepthLimitError" do
        expect { result }.to raise_error(Serega::DepthLimitError, "Relations nest in a cycle")
      end
    end
  end
end
