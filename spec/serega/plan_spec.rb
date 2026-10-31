# frozen_string_literal: true

RSpec.describe Serega::SeregaPlan do
  let(:base_class) { Class.new(Serega) }

  let(:a) do
    serializer = Class.new(base_class)

    serializer.attribute :a1
    serializer.attribute :a2
    serializer.attribute :a3, hide: true

    serializer.attribute :b, serializer: b, hide: true
    serializer.attribute :c, serializer: c, hide: true
    serializer.attribute :d, serializer: d
    serializer
  end

  let(:b) do
    serializer = Class.new(base_class)
    serializer.attribute :b1
    serializer.attribute :b2
    serializer.attribute :b3, hide: true
    serializer
  end

  let(:c) do
    serializer = Class.new(base_class)
    serializer.attribute :c1
    serializer.attribute :c2
    serializer.attribute :c3, hide: true
    serializer
  end

  let(:d) do
    serializer = Class.new(base_class)
    serializer.attribute :d1
    serializer.attribute :d2
    serializer.attribute :d3, hide: true
    serializer
  end

  let(:current_serializer) { a }

  def plan(modifiers)
    described_class.new(Serega::SeregaPlan::Selection.new(current_serializer, modifiers))
  end

  def satisfy_attribute_names(names)
    satisfy do |result|
      expect(result.points.count).to eq names.count

      names.each do |key, child_keys|
        point = result.points.find { |point| point.name == key }
        expect(point).not_to be_nil
        expect(point.child_plan).to satisfy_attribute_names(child_keys) if child_keys
      end
    end
  end

  describe "#initialize" do
    it "makes the points and the child plans of the selected attributes" do
      result = plan(with: {c: {c3: {}}})

      expect(result).to satisfy_attribute_names(
        a1: nil,
        a2: nil,
        c: {c1: nil, c2: nil, c3: nil},
        d: {d1: nil, d2: nil}
      )
    end

    context "with cyclic relations" do
      let(:current_serializer) { post_serializer }
      let(:post_depth_limit) { 2 }
      let(:comment_depth_limit) { nil }
      let(:with) { {comments: {post: {}}} }

      let(:post_serializer) do
        depth_limit = post_depth_limit
        comments = -> { comment_serializer }
        Class.new(base_class) do
          config.depth_limit = depth_limit
          attribute :title
          attribute :comments, serializer: comments, many: true, hide: true
        end
      end

      let(:comment_serializer) do
        depth_limit = comment_depth_limit
        post = -> { post_serializer }
        Class.new(base_class) do
          config.depth_limit = depth_limit
          attribute :text
          attribute :post, serializer: post, many: false, hide: true
        end
      end

      it "raises DepthLimitError with the path deeper than the root serializer limit" do
        expect { plan(with: with) }.to raise_error(Serega::DepthLimitError, "Depth limit was exceeded") do |error|
          expect(error.details).to eq "#{post_serializer} (depth limit: 2) -> comments -> post"
        end
      end

      context "when the plan depth equals the limit" do
        let(:with) { {comments: {}} }

        it "returns the plan" do
          expect(plan(with: with)).to satisfy_attribute_names(title: nil, comments: {text: nil})
        end
      end

      context "when only a relation serializer allows the depth" do
        let(:comment_depth_limit) { 5 }

        it "raises DepthLimitError" do
          expect { plan(with: with) }.to raise_error(Serega::DepthLimitError, "Depth limit was exceeded")
        end
      end

      context "without a depth limit" do
        let(:post_depth_limit) { nil }

        it "returns the plan" do
          expect(plan(with: with)).to satisfy_attribute_names(title: nil, comments: {text: nil, post: {title: nil}})
        end
      end
    end
  end

  describe "#preload_points" do
    subject(:preload_points) { described_class.new(selection).preload_points }

    let(:selection) { Serega::SeregaPlan::Selection.new(current_serializer, {}) }

    let(:current_serializer) do
      Class.new(base_class) do
        attribute :name
        attribute :posts, preload: :posts, value: proc { [] }
      end
    end

    it "returns the points with preloads" do
      expect(preload_points.map(&:name)).to eq [:posts]
    end

    context "when the selection gives a point no preloads" do
      let(:selection) do
        selection_class = Class.new(Serega::SeregaPlan::Selection) { def preloads(_attribute) = nil }
        selection_class.new(current_serializer, {})
      end

      it "returns no points" do
        expect(preload_points).to be_empty
      end
    end
  end

  describe "#flat?" do
    subject(:flat) { plan({}).flat? }

    let(:current_serializer) { Class.new(base_class) { attribute :name } }

    it "returns true" do
      expect(flat).to be true
    end

    context "with a relation" do
      let(:current_serializer) do
        child = b
        Class.new(base_class) { attribute :posts, serializer: child }
      end

      it "returns false" do
        expect(flat).to be false
      end
    end

    context "with a preload" do
      let(:current_serializer) do
        Class.new(base_class) { attribute :posts, preload: :posts, value: proc { [] } }
      end

      it "returns false" do
        expect(flat).to be false
      end
    end

    context "with a batch loader" do
      let(:current_serializer) do
        Class.new(base_class) do
          batch :count, ->(sources) { sources.to_h { |source| [source, 1] } }
          attribute :count, batch: true
        end
      end

      it "returns false" do
        expect(flat).to be false
      end
    end

    context "with a presenter" do
      let(:current_serializer) do
        Class.new(base_class) do
          presenter { def name = "Ann" }
          attribute :name
        end
      end

      it "returns false" do
        expect(flat).to be false
      end
    end
  end

  describe "#presenter" do
    subject(:presenter) { plan({}).presenter }

    let(:current_serializer) do
      Class.new(base_class) do
        presenter { def name = "Ann" }
        attribute :name
      end
    end

    it "returns the presenter of the serializer" do
      expect(presenter).to be current_serializer.presenter
    end

    context "when the serializer is shareable", if: defined?(Ractor) do
      let(:current_serializer) do
        Class.new(base_class) do
          presenter { def name = "Ann" }
          attribute :name
          make_shareable!
        end
      end

      it "returns the presenter subclass of the Ractor" do
        expect(presenter).to be current_serializer.local_presenter
        expect(presenter.superclass).to be current_serializer.presenter
      end
    end
  end

  describe "#direct_hash_builder" do
    subject(:current_plan) { plan({}) }

    let(:current_serializer) { Class.new(base_class) { attribute :name } }

    it "returns the hash result builder" do
      expect(current_plan.direct_hash_builder).to equal current_plan.result_builder(:hash)
    end

    context "when the selection gives another builder class" do
      subject(:current_plan) { described_class.new(selection) }

      let(:selection) do
        selection_class = Class.new(Serega::SeregaPlan::Selection) { def builder_class = Class.new(Serega::SeregaResultBuilder) }
        selection_class.new(current_serializer, {})
      end

      it "returns nil" do
        expect(current_plan.direct_hash_builder).to be_nil
      end
    end

    context "with a relation" do
      let(:current_serializer) do
        child = b
        Class.new(base_class) { attribute :posts, serializer: child }
      end

      it "returns nil" do
        expect(current_plan.direct_hash_builder).to be_nil
      end
    end

    context "with prepared initial objects" do
      let(:current_serializer) do
        Class.new(base_class) do
          prepare_initial_objects { |objects| objects }
          attribute :name
        end
      end

      it "returns nil" do
        expect(current_plan.direct_hash_builder).to be_nil
      end
    end

    context "with a relation plan" do
      subject(:current_plan) { plan({}).points.first.child_plan }

      let(:current_serializer) do
        child = Class.new(base_class) { attribute :title }
        Class.new(base_class) { attribute :post, serializer: child }
      end

      it "returns nil" do
        expect(current_plan.direct_hash_builder).to be_nil
      end
    end
  end

  describe "#result_builder" do
    let(:current_plan) { plan(only: {a1: {}}) }

    it "returns the result builder of the plan in the mode" do
      expect(current_plan.result_builder(:struct))
        .to be_a(current_serializer::SeregaResultBuilder)
        .and have_attributes(mode: :struct)
    end

    it "returns the same result builder for the same mode" do
      expect(current_plan.result_builder(:struct)).to equal current_plan.result_builder(:struct)
    end

    it "returns separate result builders for different modes" do
      expect(current_plan.result_builder(:hash)).not_to equal current_plan.result_builder(:struct)
    end

    context "when the selection gives another builder class" do
      let(:current_plan) { described_class.new(selection) }
      let(:builder_class) { Class.new(Serega::SeregaResultBuilder) }

      let(:selection) do
        selection_builder_class = builder_class
        selection_class = Class.new(Serega::SeregaPlan::Selection) { define_method(:builder_class) { selection_builder_class } }
        selection_class.new(current_serializer, {only: {a1: {}, d: {}}})
      end

      it "returns the result builder of the builder class" do
        expect(current_plan.result_builder(:hash)).to be_a(builder_class)
      end

      it "returns the result builder of its own selection in a child plan" do
        child_plan = current_plan.points.find(&:child_plan).child_plan

        expect(child_plan.result_builder(:hash)).to be_an_instance_of(Serega::SeregaResultBuilder)
      end
    end
  end
end
