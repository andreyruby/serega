# frozen_string_literal: true

RSpec.describe Serega::SeregaPlan::DepthLimit do
  describe ".depth_left" do
    subject(:depth_left) { described_class.depth_left(post_serializer, parent_plan_point) }

    let(:user_depth_limit) { 3 }
    let(:post_depth_limit) { nil }

    let(:post_serializer) do
      depth_limit = post_depth_limit
      Class.new(Serega) { config.depth_limit = depth_limit }
    end

    let(:user_serializer) do
      depth_limit = user_depth_limit
      posts = post_serializer
      Class.new(Serega) do
        config.depth_limit = depth_limit
        attribute :posts, serializer: posts, hide: true
      end
    end

    let(:parent_plan_point) do
      Serega::SeregaPlan::Point.new(default_plan(user_serializer), user_serializer.attributes[:posts], nil, nil)
    end

    it "returns one level less than the parent plan has" do
      expect(depth_left).to eq 2
    end

    context "when the parent plan has one level left" do
      let(:user_depth_limit) { 1 }

      it "raises DepthLimitError with the path and the serializer whose limit applies" do
        expect { depth_left }.to raise_error(Serega::DepthLimitError, "Depth limit was exceeded") do |error|
          expect(error.details).to eq "#{user_serializer} (depth limit: 1) -> posts\n(hint: if the nesting is not a cycle, increase config.depth_limit of #{user_serializer})"
        end
      end
    end

    context "when only the child serializer has a depth limit" do
      let(:user_depth_limit) { nil }
      let(:post_depth_limit) { 1 }

      it "returns nil" do
        expect(depth_left).to be_nil
      end
    end

    context "without a parent plan point" do
      let(:parent_plan_point) { nil }
      let(:post_depth_limit) { 4 }

      it "returns the depth limit of the serializer" do
        expect(depth_left).to eq 4
      end
    end
  end
end
