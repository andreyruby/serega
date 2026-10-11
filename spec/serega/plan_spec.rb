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
  let(:described_class) { current_serializer::SeregaPlan }

  def plan(opts)
    current_serializer::SeregaPlan.new(nil, opts)
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
    it "returns plan with all not hidden attributes by default" do
      result = plan({})

      expect(result).to satisfy_attribute_names(
        a1: nil,
        a2: nil,
        d: {d1: nil, d2: nil}
      )
    end

    it "returns only attributes from :only option" do
      result = plan(only: {a2: {}, d: {d1: {}}}, except: {}, with: {})

      expect(result).to satisfy_attribute_names(
        a2: nil,
        d: {d1: nil}
      )
    end

    it "returns all not hidden attributes except provided in :except option" do
      result = plan(only: {}, except: {a2: {}, d: {d1: {}}}, with: {})

      expect(result).to satisfy_attribute_names(
        a1: nil,
        d: {d2: nil}
      )
    end

    it "returns all not hidden attributes and attributes defined in :with option" do
      result = plan(only: {}, except: {}, with: {a3: {}, b: {}, c: {c3: {}}})

      expect(result).to satisfy_attribute_names(
        a1: nil,
        a2: nil,
        a3: nil,
        b: {b1: nil, b2: nil},
        c: {c1: nil, c2: nil, c3: nil},
        d: {d1: nil, d2: nil}
      )
    end
  end

  describe "#preload_points" do
    subject(:preload_points) { plan({}).preload_points }

    let(:current_serializer) do
      Class.new(base_class) do
        attribute :name
        attribute :posts, preload: :posts, value: proc { [] }
      end
    end

    it "returns the points with preloads" do
      expect(preload_points.map(&:name)).to eq [:posts]
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
  end
end
