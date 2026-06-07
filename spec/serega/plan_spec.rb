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
    current_serializer::SeregaPlan.call(opts)
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

  describe ".call" do
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

  describe "saving plans to cache" do
    it "does not save plans to cache when not configured to do so" do
      result1 = plan(only: {a1: {}})
      result2 = plan(only: {a1: {}})

      expect(result1).to satisfy_attribute_names(a1: nil)
      expect(result2).to satisfy_attribute_names(a1: nil)
      expect(result1).not_to equal result2
    end

    it "saves plans to cache and uses them when configured to use cache" do
      current_serializer.config.max_cached_plans_per_serializer_count = 1
      result1 = plan(only: {a1: {}})
      result2 = plan(only: {a1: {}})

      expect(result1).to satisfy_attribute_names(a1: nil)
      expect(result2).to satisfy_attribute_names(a1: nil)
      expect(result1).to equal result2
    end

    it "removes from cache oldest plans if cached keys count more than configured" do
      current_serializer.config.max_cached_plans_per_serializer_count = 1

      result1 = plan(only: {a1: {}})
      plan(only: {a2: {}}) # replace cached result1

      result2 = plan(only: {a1: {}})

      expect(result1).to satisfy_attribute_names(a1: nil)
      expect(result2).to satisfy_attribute_names(a1: nil)
      expect(result1).not_to equal result2
    end
  end

  describe ".data_class_for" do
    it "returns a Data subclass with the given members" do
      data_class = described_class.data_class_for(%i[x y])
      expect(data_class).to be < Data
      expect(data_class.members).to eq %i[x y]
    end

    it "returns the same object on repeated calls with the same names" do
      first = described_class.data_class_for(%i[a b])
      second = described_class.data_class_for(%i[a b])
      expect(first).to equal second
    end

    it "returns different objects for different names" do
      one = described_class.data_class_for(%i[a])
      two = described_class.data_class_for(%i[b])
      expect(one).not_to equal two
    end

    it "caches independently per plan class (per serializer)" do
      other_plan = Class.new(base_class)::SeregaPlan
      klass_a = described_class.data_class_for(%i[x])
      klass_b = other_plan.data_class_for(%i[x])
      expect(klass_a).not_to equal klass_b
    end
  end

  describe "#data_class" do
    it "returns a Data subclass whose members match the plan's visible fields" do
      p = plan(only: {a1: {}, a2: {}})
      expect(p.data_class.members).to match_array(%i[a1 a2])
    end

    it "returns the same Data class on repeated calls for the same plan" do
      p = plan(only: {a1: {}})
      expect(p.data_class).to equal p.data_class
    end

    it "returns the same Data class for plans with identical fields across instances" do
      p1 = plan(only: {a1: {}})
      p2 = plan(only: {a1: {}})
      expect(p1).not_to equal p2
      expect(p1.data_class).to equal p2.data_class
    end

    it "returns different Data classes for plans with different fields" do
      p1 = plan(only: {a1: {}})
      p2 = plan(only: {a2: {}})
      expect(p1.data_class).not_to equal p2.data_class
    end
  end
end
