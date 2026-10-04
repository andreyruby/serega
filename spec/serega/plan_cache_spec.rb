# frozen_string_literal: true

RSpec.describe Serega::SeregaPlanCache do
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
    current_serializer.plan_cache.fetch(modifiers[:only], modifiers[:with], modifiers[:except])
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

  describe "caching the plan without modifiers" do
    it "reuses the plan without modifiers when plans cache is disabled" do
      result1 = plan({})
      result2 = plan(only: {}, with: {}, except: {})

      expect(result1).to satisfy_attribute_names(a1: nil, a2: nil, d: {d1: nil, d2: nil})
      expect(result1).to equal result2
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

    it "caches plans built with other initiate options" do
      current_serializer.config.max_cached_plans_per_serializer_count = 1
      result1 = current_serializer.new(only: :a1, check_initiate_params: false).plan
      result2 = current_serializer.new(only: :a1, check_initiate_params: false).plan

      expect(result1).to satisfy_attribute_names(a1: nil)
      expect(result1).to equal result2
    end

    it "caches plans with the same attribute names in different nesting separately" do
      current_serializer.config.max_cached_plans_per_serializer_count = 2
      nested = plan(only: {d: {d1: {}}})
      flat = plan(only: {d: {}, d1: {}})

      expect(nested).to satisfy_attribute_names(d: {d1: nil})
      expect(flat).to satisfy_attribute_names(d: {d1: nil, d2: nil})
    end

    it "keeps cached plans when provided modifiers are changed later" do
      current_serializer.config.max_cached_plans_per_serializer_count = 1
      only = {a1: {}}
      result1 = plan(only: only)
      only[:a2] = {}

      expect(plan(only: {a1: {}})).to equal result1
    end

    it "validates cached modifiers once" do
      current_serializer.config.max_cached_plans_per_serializer_count = 1
      allow(Serega::SeregaValidations::Initiate::CheckModifiers).to receive(:new).and_call_original

      2.times { current_serializer.new(only: :a1) }

      expect(Serega::SeregaValidations::Initiate::CheckModifiers).to have_received(:new).once
    end

    it "shares cached plans between calls with and without validation" do
      current_serializer.config.max_cached_plans_per_serializer_count = 1
      result1 = current_serializer.plan_cache.fetch({a1: {}}, nil, nil, check_initiate_params: false)
      result2 = current_serializer.plan_cache.fetch({a1: {}}, nil, nil, check_initiate_params: true)

      expect(result2).to equal result1
    end

    it "validates cached modifiers that were not validated when cached" do
      current_serializer.config.max_cached_plans_per_serializer_count = 1
      current_serializer.new(only: :foo, check_initiate_params: false)

      expect { current_serializer.new(only: :foo) }.to raise_error Serega::AttributeNotExist
    end

    it "validates other initiate options with cached modifiers" do
      current_serializer.config.max_cached_plans_per_serializer_count = 1
      current_serializer.new(only: :a1)

      expect { current_serializer.new(only: :a1, foo: 1) }.to raise_error Serega::SeregaError, /foo/
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
end
